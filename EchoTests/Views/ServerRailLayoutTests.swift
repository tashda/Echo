import Foundation
import Testing
@testable import Echo

/// The rail's groups (round 55): open above minimized with a hairline, and the recents pill.
@Suite("Server Rail Layout")
struct ServerRailLayoutTests {
    private let a = UUID(), b = UUID(), c = UUID(), d = UUID(), e = UUID(), f = UUID(), g = UUID()

    private func layout(
        sessions: [UUID] = [],
        pending: [UUID] = [],
        minimized: Set<UUID> = [],
        recents: [UUID] = [],
        connecting: Set<UUID> = [],
        shows: Bool = true,
        limit: Int = 5
    ) -> ServerRailLayout {
        ServerRailLayout(
            sessionIDs: sessions,
            pendingIDs: pending,
            minimizedIDs: minimized,
            recentCandidates: recents,
            connectingFromRecents: connecting,
            showsRecents: shows,
            recentLimit: limit
        )
    }

    @Test func open_servers_come_first_then_minimized_each_in_connection_order() {
        let result = layout(sessions: [a, b, c, d], minimized: [a, c])
        #expect(result.openIDs == [b, d])
        #expect(result.minimizedIDs == [a, c])
        #expect(result.connectedIDs == [b, d, a, c])
    }

    @Test func the_hairline_shows_only_when_both_groups_have_a_server() {
        #expect(layout(sessions: [a, b], minimized: [b]).showsHairline)
        #expect(!layout(sessions: [a, b]).showsHairline)
        #expect(!layout(sessions: [a, b], minimized: [a, b]).showsHairline)
        #expect(!layout(sessions: []).showsHairline)
    }

    @Test func minimizing_moves_an_item_below_the_line_and_restoring_moves_it_back() {
        let before = layout(sessions: [a, b, c])
        let minimized = layout(sessions: [a, b, c], minimized: [a])
        let restored = layout(sessions: [a, b, c], minimized: [])
        #expect(before.connectedIDs == [a, b, c])
        #expect(minimized.connectedIDs == [b, c, a])
        #expect(restored == before)
    }

    @Test func a_connecting_server_is_open_and_never_minimized() {
        let result = layout(sessions: [a], pending: [b], minimized: [a, b])
        #expect(result.openIDs == [b])
        #expect(result.minimizedIDs == [a])
    }

    @Test func offsets_and_height_count_the_hairline() {
        let two = layout(sessions: [a, b], minimized: [b])
        let item: CGFloat = 34, gap: CGFloat = 4
        let block = ServerRailLayout.hairlineBlockHeight
        #expect(two.offset(of: a, itemSize: item, spacing: gap) == 0)
        #expect(two.offset(of: b, itemSize: item, spacing: gap) == item + gap + block + gap)
        #expect(two.connectedHeight(itemSize: item, spacing: gap) == 2 * item + block + 2 * gap)
        let plain = layout(sessions: [a, b])
        #expect(plain.offset(of: b, itemSize: item, spacing: gap) == item + gap)
        #expect(plain.connectedHeight(itemSize: item, spacing: gap) == 2 * item + gap)
        #expect(plain.offset(of: c, itemSize: item, spacing: gap) == nil)
    }

    @Test func recents_are_saved_servers_that_are_not_connected_most_recent_first() {
        let result = layout(sessions: [a], pending: [b], recents: [a, c, b, d, c, e])
        #expect(result.recentIDs == [c, d, e])
    }

    @Test func recents_stop_at_the_limit() {
        let result = layout(recents: [a, b, c, d, e, f, g], limit: 3)
        #expect(result.recentIDs == [a, b, c])
        #expect(layout(recents: [a, b], limit: 5).recentIDs == [a, b])
    }

    @Test func recents_are_empty_when_the_setting_is_off() {
        #expect(layout(recents: [a, b], shows: false).recentIDs.isEmpty)
        #expect(layout(recents: [a, b], limit: 0).recentIDs.isEmpty)
    }

    @Test func a_disconnected_server_drops_to_the_top_of_the_recents() {
        let before = layout(sessions: [a], recents: [b, c])
        #expect(before.recentIDs == [b, c])
        // After the disconnect the store moves it to the front of its history.
        let after = layout(sessions: [], recents: [a, b, c])
        #expect(after.recentIDs == [a, b, c])
        #expect(after.connectedIDs.isEmpty)
    }

    @Test func a_recent_that_is_connecting_stays_in_the_recents_until_it_has_a_session() {
        let connecting = layout(sessions: [a], pending: [b], recents: [b, c], connecting: [b])
        #expect(connecting.recentIDs == [b, c])
        #expect(connecting.connectedIDs == [a])

        let connected = layout(sessions: [a, b], recents: [b, c], connecting: [b])
        #expect(connected.recentIDs == [c])
        #expect(connected.connectedIDs == [a, b])
    }

    @Test func a_failed_connection_from_the_recents_moves_to_the_connected_pill() {
        // The caller drops a failed pending from `connecting`, so it is shown as lost.
        let failed = layout(sessions: [a], pending: [b], recents: [b, c], connecting: [])
        #expect(failed.connectedIDs == [a, b])
        #expect(failed.recentIDs == [c])
    }

    // MARK: Scrolling, only when needed

    private func overflows(_ result: ServerRailLayout, railHeight: CGFloat) -> Bool {
        result.connectedPillOverflows(
            itemSize: 34, spacing: 4, padding: 4, pillGap: 8, minimumGap: 12, railHeight: railHeight
        )
    }

    @Test func the_connected_pill_scrolls_only_when_it_outgrows_the_room_above_the_circle() {
        let two = layout(sessions: [a, b])
        // Two items: 34 + 4 + 34 + 8 padding = 80; the circle takes 42 + 8 + 12 = 62.
        #expect(!overflows(two, railHeight: 142))
        #expect(overflows(two, railHeight: 141))
        #expect(!overflows(two, railHeight: .infinity))
    }

    @Test func the_recents_pill_takes_room_from_the_connected_pill() {
        let withRecents = layout(sessions: [a, b], recents: [c, d])
        // The recents pill: 34 + 4 + 34 + 8 = 80, and the gap above it, 8.
        #expect(!overflows(withRecents, railHeight: 230))
        #expect(overflows(withRecents, railHeight: 229))
    }

    // MARK: Name bubble on recents

    @Test func the_recents_stay_while_the_welcome_leaves_only_for_a_click_in_the_rail() {
        #expect(ServerRailLayout.showsRecents(setting: true, welcomeIsLeaving: false, hasClickedRecent: false))
        #expect(!ServerRailLayout.showsRecents(setting: true, welcomeIsLeaving: true, hasClickedRecent: false))
        #expect(ServerRailLayout.showsRecents(setting: true, welcomeIsLeaving: true, hasClickedRecent: true))
        #expect(!ServerRailLayout.showsRecents(setting: false, welcomeIsLeaving: false, hasClickedRecent: true))
    }

    @Test func a_resting_recent_has_no_status_line_and_a_connecting_one_says_so() {
        #expect(ServerRailBubbleCaption.recentStatus(isConnecting: false) == nil)
        #expect(ServerRailBubbleCaption.recentStatus(isConnecting: true) == "Connecting")
    }
}

@Suite("Server Trail Settings")
struct ServerTrailSettingsTests {
    @Test func defaults_show_five_recent_servers() {
        let settings = GlobalSettings()
        #expect(settings.showsRecentServers)
        #expect(settings.recentServerCount == .five)
    }

    @Test func older_stored_settings_decode_with_the_defaults() throws {
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: Data("{}".utf8))
        #expect(decoded.showsRecentServers)
        #expect(decoded.recentServerCount == .five)
    }

    @Test func the_choices_are_three_five_and_eight() {
        #expect(RecentServerCount.allCases.map(\.rawValue) == [3, 5, 8])
    }

    @Test func the_setting_round_trips() throws {
        var settings = GlobalSettings()
        settings.showsRecentServers = false
        settings.recentServerCount = .eight
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: JSONEncoder().encode(settings))
        #expect(!decoded.showsRecentServers)
        #expect(decoded.recentServerCount == .eight)
    }
}

/// Remove from Recents (round 55): every record of the connection goes, others stay.
@Suite("Recent Connection Removal")
struct RecentConnectionRemovalTests {
    private func record(_ id: UUID, database: String?) -> RecentConnectionRecord {
        RecentConnectionRecord(
            id: id, connectionName: "S", host: "h", databaseName: database, username: "u",
            databaseType: .postgresql, colorHex: nil, lastUsedAt: Date(), projectID: nil
        )
    }

    @Test func removing_a_connection_drops_all_its_records_and_keeps_the_others() {
        let a = UUID(), b = UUID()
        let records = [record(a, database: "one"), record(b, database: nil), record(a, database: "two")]
        let result = records.removing(connectionID: a)
        #expect(result.map(\.id) == [b])
    }

    @Test func removing_an_unknown_connection_changes_nothing() {
        let a = UUID()
        let records = [record(a, database: nil)]
        #expect(records.removing(connectionID: UUID()) == records)
    }
}
