import SwiftUI

extension ObjectBrowserSidebarView {
    func creationOptions(for databaseType: DatabaseType) -> [ExplorerCreationMenuItem] {
        switch databaseType {
        case .postgresql:
            return [
                .init(title: "New Table", icon: .system("tablecells")),
                .init(title: "New View", icon: .system("eye")),
                .init(title: "New Materialized View", icon: .system("eye.fill")),
                .init(title: "New Function", icon: .system("function")),
                .init(title: "New Trigger", icon: .system("bolt")),
                .init(title: "New Schema", icon: .asset("schema"))
            ]
        case .mysql:
            return [
                .init(title: "New Table", icon: .system("tablecells")),
                .init(title: "New View", icon: .system("eye")),
                .init(title: "New Function", icon: .system("function")),
                .init(title: "New Trigger", icon: .system("bolt"))
            ]
        case .microsoftSQL:
            return [
                .init(title: "New Table", icon: .system("tablecells")),
                .init(title: "New View", icon: .system("eye")),
                .init(title: "New Procedure", icon: .system("gearshape")),
                .init(title: "New Function", icon: .system("function")),
                .init(title: "New Trigger", icon: .system("bolt"))
            ]
        case .sqlite:
            return [
                .init(title: "New Table", icon: .system("tablecells")),
                .init(title: "New View", icon: .system("eye"))
            ]
        }
    }
}
