import Foundation
import Observation
import ActiveDirectory

@Observable
final class WindowsPrincipalPickerViewModel {

    enum Status: Equatable {
        case connecting
        case ready
        case searching
        case error(String)
    }

    let domain: String
    let username: String
    private let password: String

    var searchText: String = ""
    var includeUsers: Bool = true
    var includeGroups: Bool = true
    var includeComputers: Bool = false

    var status: Status = .connecting
    var results: [ADPrincipal] = []
    var truncated: Bool = false
    var selectedDNs: Set<String> = []
    var forestRoot: String?
    var hasRunSearch: Bool = false
    var lastSearchedText: String = ""

    private(set) var scopes: [LocationScope] = []
    var selectedScopeID: String = "forest"

    /// Combined catalog of forest domains + trusted external domains. Used
    /// for the principal-DN → NetBIOS lookup that builds the SQL Server
    /// account name.
    private(set) var allDomains: [ADDomain] = []

    struct LocationScope: Identifiable, Hashable {
        enum Kind: Hashable { case forest, domain, trusted }
        let id: String
        let displayName: String
        let kind: Kind
        let baseDN: String?
        let dnsRoot: String?
    }

    var selectedScope: LocationScope? {
        scopes.first(where: { $0.id == selectedScopeID })
    }

    var selectedBaseDN: String? {
        selectedScope?.baseDN
    }

    var selectedScopeDisplayName: String {
        selectedScope?.displayName ?? "Entire Forest"
    }

    /// Forest-wide GC session used for `.forest` and the root-domain scope.
    private var forestSession: ADBrowser.ForestSession?
    /// Per-trusted-domain DC sessions, created on demand the first time the
    /// user selects a trusted scope. Cached for the lifetime of the picker.
    private var trustedSessions: [String: ADClient] = [:]
    /// User's home Kerberos realm in DNS form (e.g. `global.cashmgmt.net`).
    /// Discovered when the forest session opens and used as the realm for
    /// every cross-realm bind to a trusted domain — the trust handles the
    /// referral so we never try to authenticate against the foreign realm
    /// directly.
    private var homeRealm: String?

    init(domain: String, username: String, password: String) {
        self.domain = domain
        self.username = username
        self.password = password
    }

    var selectedPrincipals: [ADPrincipal] {
        results.filter { selectedDNs.contains($0.distinguishedName) }
    }

    /// Builds the SQL-Server-friendly `DOMAIN\sAMAccountName` for a principal.
    ///
    /// SQL Server's `CREATE LOGIN ... FROM WINDOWS` accepts UPN form in
    /// theory, but in practice rejects any UPN whose suffix the local SQL
    /// host's AD can't resolve — which is exactly what happens with custom
    /// UPN suffixes like `@loomis.com` on accounts whose actual realm is
    /// `GLOBAL.CASHMGMT.NET`. The NetBIOS form `GLOBAL\svc_…` is the only
    /// shape SQL Server reliably accepts, so we always emit it.
    ///
    /// Lookup order:
    /// 1. The principal's home domain in the catalog (its `nETBIOSName`).
    /// 2. The catalog-derived home-domain entry that connect() synthesizes
    ///    when the forest's partitions container wasn't readable.
    /// 3. A last-ditch synthesis from the leftmost `DC=` label of the
    ///    principal's DN, uppercased — works for the typical case where
    ///    the NetBIOS short name matches the leftmost DNS label.
    func sqlServerAccountName(for principal: ADPrincipal) -> String {
        let netbios = netBIOSName(forPrincipalDN: principal.distinguishedName)
            ?? syntheticNetBIOSName(forDN: principal.distinguishedName)
        return "\(netbios)\\\(principal.sAMAccountName)"
    }

    func displayDomain(for principal: ADPrincipal) -> String {
        if let netbios = netBIOSName(forPrincipalDN: principal.distinguishedName),
           !netbios.isEmpty {
            return netbios
        }
        return syntheticNetBIOSName(forDN: principal.distinguishedName)
    }

    private func netBIOSName(forPrincipalDN dn: String) -> String? {
        let lowered = dn.lowercased()
        var best: ADDomain?
        for d in allDomains where !d.namingContext.isEmpty {
            let suffix = "," + d.namingContext.lowercased()
            let exact = d.namingContext.lowercased()
            if lowered.hasSuffix(suffix) || lowered == exact {
                if (best?.namingContext.count ?? -1) < d.namingContext.count {
                    best = d
                }
            }
        }
        let value = best?.netBIOSName ?? ""
        return value.isEmpty ? nil : value
    }

    /// Extracts the leftmost `DC=` label from a DN and uppercases it.
    /// Used as the last-resort NetBIOS name when the catalog lookup fails.
    /// `CN=svc,OU=Users,DC=global,DC=cashmgmt,DC=net` → `GLOBAL`.
    private func syntheticNetBIOSName(forDN dn: String) -> String {
        let firstDC = dn
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.lowercased().hasPrefix("dc=") }
            .map { String($0.dropFirst(3)) }
        return (firstDC ?? "").uppercased()
    }

    // MARK: - Connect

    func connect() async {
        if forestSession != nil { return }
        status = .connecting
        do {
            let session = try await ADBrowser.openForestCatalog(
                anyDomainInForest: domain,
                credentials: ADCredentials(method: .kerberos(
                    domain: domain,
                    user: username,
                    password: password
                ))
            )
            self.forestSession = session
            self.forestRoot = session.forestRoot
            // The forest root IS the user's home Kerberos realm in DNS form.
            // We need it for cross-realm trust binds — Heimdal must request
            // a TGT against this realm and follow trust referrals from there.
            self.homeRealm = session.forestRoot

            // Forest's own domains.
            let forestDomains: [ADDomain] = (try? await session.client.listForestDomains()) ?? []
            // External trusted domains — only ones with outbound or
            // bidirectional trust, since those are the ones we can actually
            // search with our credentials.
            let trustedDomains: [ADDomain] = (try? await session.client.listTrustedDomains()) ?? []

            // Always ensure the home domain is in `allDomains` so the
            // NetBIOS lookup that builds the SQL Server account name never
            // falls through to an unusable UPN/FQDN fallback. When
            // listForestDomains came back empty (some tenants restrict the
            // partitions read), we synthesize an entry from the root
            // naming context's leftmost DC label.
            let home = homeDomainEntry(
                forestDomains: forestDomains,
                rootDomainNC: session.rootDomainNamingContext,
                forestRoot: session.forestRoot
            )
            var forestPlusHome = forestDomains
            if !forestPlusHome.contains(where: { $0.namingContext.caseInsensitiveCompare(home.namingContext) == .orderedSame }) {
                forestPlusHome.insert(home, at: 0)
            }
            self.allDomains = forestPlusHome + trustedDomains
            self.scopes = makeScopes(
                forestRoot: session.forestRoot,
                rootDomainNC: session.rootDomainNamingContext,
                forestDomains: forestPlusHome,
                trustedDomains: trustedDomains
            )
            self.selectedScopeID = scopes.first(where: { $0.baseDN == session.rootDomainNamingContext })?.id ?? "forest"
            self.status = .ready
        } catch let error as ADError {
            status = .error(Self.message(for: error))
        } catch {
            status = .error("Failed to open forest catalog: \(error.localizedDescription)")
        }
    }

    func disconnect() async {
        if let client = forestSession?.client {
            await client.close()
        }
        forestSession = nil
        for (_, client) in trustedSessions {
            await client.close()
        }
        trustedSessions.removeAll()
    }

    private func homeDomainEntry(forestDomains: [ADDomain], rootDomainNC: String, forestRoot: String) -> ADDomain {
        if let existing = forestDomains.first(where: { $0.namingContext.caseInsensitiveCompare(rootDomainNC) == .orderedSame }) {
            return existing
        }
        // Synthesize. NetBIOS short name almost always matches the
        // leftmost DNS label uppercased — true for every AD domain I've
        // seen in practice and matches Microsoft's default behavior when
        // promoting a DC.
        let netbios = String(forestRoot.split(separator: ".").first ?? "").uppercased()
        return ADDomain(
            dnsRoot: forestRoot,
            netBIOSName: netbios,
            namingContext: rootDomainNC
        )
    }

    private func makeScopes(
        forestRoot: String,
        rootDomainNC: String,
        forestDomains: [ADDomain],
        trustedDomains: [ADDomain]
    ) -> [LocationScope] {
        var scopes: [LocationScope] = [
            LocationScope(
                id: "forest",
                displayName: "Entire Forest (\(forestRoot))",
                kind: .forest,
                baseDN: nil,
                dnsRoot: forestRoot
            )
        ]

        func display(for domain: ADDomain) -> String {
            switch (domain.netBIOSName.isEmpty, domain.dnsRoot.isEmpty) {
            case (false, false): return "\(domain.netBIOSName) (\(domain.dnsRoot))"
            case (false, true): return domain.netBIOSName
            case (true, false): return domain.dnsRoot
            case (true, true): return domain.namingContext
            }
        }

        // Root domain first…
        if let root = forestDomains.first(where: { $0.namingContext.caseInsensitiveCompare(rootDomainNC) == .orderedSame }) {
            scopes.append(LocationScope(
                id: root.namingContext,
                displayName: display(for: root),
                kind: .domain,
                baseDN: root.namingContext,
                dnsRoot: root.dnsRoot
            ))
        } else {
            // Synthesize an entry from the rootDomainNamingContext when the
            // partitions container wasn't readable (some tenants restrict
            // access). The DNS root is reconstructable from the DCs.
            let dnsRoot = rootDomainNC
                .split(separator: ",")
                .filter { $0.lowercased().hasPrefix("dc=") }
                .map { $0.dropFirst(3) }
                .joined(separator: ".")
            let netbios = String(dnsRoot.split(separator: ".").first ?? "").uppercased()
            scopes.append(LocationScope(
                id: rootDomainNC,
                displayName: netbios.isEmpty ? dnsRoot : "\(netbios) (\(dnsRoot))",
                kind: .domain,
                baseDN: rootDomainNC,
                dnsRoot: dnsRoot
            ))
        }

        // …then other forest domains…
        let children = forestDomains
            .filter { $0.namingContext.caseInsensitiveCompare(rootDomainNC) != .orderedSame }
            .sorted { $0.dnsRoot.localizedCaseInsensitiveCompare($1.dnsRoot) == .orderedAscending }
        for child in children {
            scopes.append(LocationScope(
                id: child.namingContext,
                displayName: display(for: child),
                kind: .domain,
                baseDN: child.namingContext,
                dnsRoot: child.dnsRoot
            ))
        }

        // …then every trusted external domain.
        let trusted = trustedDomains
            .sorted { $0.dnsRoot.localizedCaseInsensitiveCompare($1.dnsRoot) == .orderedAscending }
        for t in trusted {
            scopes.append(LocationScope(
                id: t.namingContext,
                displayName: display(for: t),
                kind: .trusted,
                baseDN: t.namingContext,
                dnsRoot: t.dnsRoot
            ))
        }
        return scopes
    }

    // MARK: - Search

    func runSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        status = .searching

        let filter = ADSearchQuery.Filter(
            text: query,
            includeUsers: includeUsers,
            includeGroups: includeGroups,
            includeComputers: includeComputers,
            includeOrganizationalUnits: false
        )

        do {
            let (client, baseDN) = try await resolveClientAndBaseDN()
            let adQuery = ADSearchQuery(
                filter: filter,
                scope: .forest(anyDomainInForest: domain),
                baseDNOverride: baseDN,
                maxResults: 500
            )
            let outcome = try await client.search(adQuery)
            if Task.isCancelled { return }
            results = outcome.principals
            truncated = outcome.truncated
            selectedDNs.formIntersection(outcome.principals.map(\.distinguishedName))
            lastSearchedText = query
            hasRunSearch = true
            status = .ready
        } catch let error as ADError {
            if Task.isCancelled { return }
            status = .error(Self.message(for: error))
        } catch {
            if Task.isCancelled { return }
            status = .error(error.localizedDescription)
        }
    }

    /// Returns the right LDAP client for the currently selected scope.
    /// Forest and forest-domain scopes use the Global Catalog session;
    /// trusted external domains get their own DC bind on first selection,
    /// cached for the lifetime of the picker.
    private func resolveClientAndBaseDN() async throws -> (ADClient, String?) {
        guard let scope = selectedScope else {
            guard let gc = forestSession?.client else { throw ADError.notBound }
            return (gc, nil)
        }
        switch scope.kind {
        case .forest:
            guard let gc = forestSession?.client else { throw ADError.notBound }
            return (gc, nil)
        case .domain:
            guard let gc = forestSession?.client else { throw ADError.notBound }
            return (gc, scope.baseDN)
        case .trusted:
            guard let dnsRoot = scope.dnsRoot else { throw ADError.invalidArgument("Trusted scope has no DNS root") }
            if let cached = trustedSessions[scope.id] {
                return (cached, scope.baseDN)
            }
            // Use the user's *home* realm for the Kerberos bind, NOT the
            // target trusted domain. The trust between the realms is what
            // makes the cross-domain LDAP bind possible — Heimdal asks our
            // KDC for a referral TGT to the trusted realm and then a
            // service ticket for that DC's LDAP service. Passing the
            // trusted domain as the realm here would try to authenticate
            // adm.kberg@TRUSTED.REALM, which doesn't exist.
            let client = try await ADBrowser.openDomainController(
                domain: dnsRoot,
                credentials: ADCredentials(method: .kerberos(
                    domain: homeRealm ?? domain,
                    user: username,
                    password: password
                ))
            )
            trustedSessions[scope.id] = client
            return (client, scope.baseDN)
        }
    }

    // MARK: - Error formatting

    private static func message(for error: ADError) -> String {
        switch error {
        case let .discoveryFailed(reason):
            return "Could not locate Active Directory servers — \(reason)"
        case let .bindFailed(_, reason):
            return "Sign-in to Active Directory failed — \(reason)"
        case let .kerberosFailed(reason):
            return "Kerberos authentication failed — \(reason)"
        case let .searchFailed(_, reason):
            return "Active Directory search failed — \(reason)"
        case .tlsTrustRejected:
            return "The directory server's TLS certificate was not trusted."
        case .unsupportedTransport:
            return "Unsupported transport for Active Directory."
        case let .invalidArgument(detail):
            return "Invalid argument: \(detail)"
        case .notBound:
            return "Not connected to Active Directory."
        }
    }
}
