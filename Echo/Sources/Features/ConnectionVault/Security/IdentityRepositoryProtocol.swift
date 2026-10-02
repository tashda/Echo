import Foundation

@MainActor
protocol IdentityRepositoryProtocol: AnyObject, Sendable {
    func password(for connection: SavedConnection) -> String?
    func password(for identity: SavedIdentity) -> String?
    
    func setPassword(_ password: String, for connection: inout SavedConnection) throws
    func setPassword(_ password: String, for identity: inout SavedIdentity) throws
    
    func deletePassword(for connection: SavedConnection)
    func deletePassword(for identity: SavedIdentity)
    
    func resolveCredentials(for connection: SavedConnection, overridePassword: String?) -> ConnectionCredentials?
    func resolveAuthenticationConfiguration(for connection: SavedConnection, overridePassword: String?) -> DatabaseAuthenticationConfiguration?
}
