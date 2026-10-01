import AppKit
import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("Explorer menu rules (round 42)")
struct ExplorerMenuRulesTests {
    private func menu(_ build: (NSMenu) -> Void) -> NSMenu {
        let menu = NSMenu()
        build(menu)
        return menu
    }

    @Test func iconsStayOnlyOnFamiliarActions() {
        let result = menu { menu in
            menu.addActionItem("New Query", systemImage: "plus.rectangle") {}
            menu.addActionItem("Activity Monitor", systemImage: "gauge.with.dots.needle.33percent") {}
            menu.addCopyName("x")
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {}
            menu.addActionItem("Properties", systemImage: "info.circle") {}
            menu.addActionItem("Drop Table", systemImage: "trash") {}
        }.applyingExplorerRules()
        let withIcon = result.items.filter { $0.image != nil }.map(\.title)
        #expect(withIcon == ["New Query", "Copy Name", "Refresh", "Properties", "Drop Table"])
    }

    @Test func submenuItemsAreStrippedToo() {
        let result = menu { menu in
            menu.addSubmenu("Open Tool", systemImage: "wrench") { $0.addActionItem("Maintenance", systemImage: "wrench") {} }
        }.applyingExplorerRules()
        #expect(result.items[0].image == nil)
        #expect(result.items[0].submenu?.items[0].image == nil)
    }

    @Test func separatorsAreTidied() {
        let result = menu { menu in
            menu.addDivider()
            menu.addActionItem("A") {}
            menu.addDivider()
            menu.addDivider()
            menu.addActionItem("B") {}
            menu.addDivider()
        }.applyingExplorerRules()
        #expect(result.items.map(\.isSeparatorItem) == [false, true, false])
    }

    @Test func refreshGoesLastInAFolderMenu() {
        let result = menu { menu in
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {}
            menu.addActionItem("New Table") {}
        }.applyingExplorerRules()
        #expect(result.items.map(\.title) == ["New Table", "", "Refresh"])
    }

    @Test func refreshStaysPutWhenTheMenuEndsInDrop() {
        let result = menu { menu in
            menu.addActionItem("Refresh") {}
            menu.addActionItem("Drop Table") {}
        }.applyingExplorerRules()
        #expect(result.items.map(\.title) == ["Refresh", "Drop Table"])
    }

    @Test func executeStatementListsEachParameter() {
        let parameters = [
            ProcedureParameterInfo(name: "@id", dataType: "int", isOutput: false, hasDefaultValue: false, maxLength: nil, ordinalPosition: 1),
            ProcedureParameterInfo(name: "@total", dataType: "money", isOutput: true, hasDefaultValue: true, maxLength: nil, ordinalPosition: 2),
        ]
        let sql = ExecuteStatementBuilder.sql(qualifiedName: "[dbo].[p]", parameters: parameters, databaseType: .microsoftSQL)
        #expect(sql == "EXEC [dbo].[p]\n    @id = NULL, -- int\n    @total = NULL OUTPUT; -- money, optional")
        #expect(ExecuteStatementBuilder.sql(qualifiedName: "[dbo].[p]", parameters: [], databaseType: .microsoftSQL) == "EXEC [dbo].[p];")
    }

    @Test func columnNamesAreQuotedPerDialect() {
        #expect(ColumnNameQuoting.quoted("a]b", databaseType: .microsoftSQL) == "[a]]b]")
        #expect(ColumnNameQuoting.quoted("a\"b", databaseType: .postgresql) == "\"a\"\"b\"")
        #expect(ColumnNameQuoting.quoted("a`b", databaseType: .mysql) == "`a``b`")
    }

    @Test func copyNameGoesBeforeDropAndProperties() {
        let result = menu { menu in
            menu.addActionItem("Script as") {}
            menu.addDivider()
            menu.addActionItem("Drop Login") {}
            menu.addDivider()
            menu.addActionItem("Properties") {}
        }.insertingCopyName("sa").applyingExplorerRules()
        #expect(result.items.map(\.title) == ["Script as", "", "Copy Name", "", "Drop Login", "", "Properties"])
    }

    @Test func filterMatchesNamesLoosely() {
        #expect(ExplorerBlueprintWalker.matches("Orders", filter: "ord"))
        #expect(ExplorerBlueprintWalker.matches("Orders", filter: nil))
        #expect(ExplorerBlueprintWalker.matches("Orders", filter: "  "))
        #expect(!ExplorerBlueprintWalker.matches("Orders", filter: "cust"))
    }

    @Test func columnRenameStatementPerDialect() {
        #expect(ColumnRenameStatement.sql(table: "[dbo].[t]", oldName: "a", newName: "b", databaseType: .microsoftSQL)
                == "EXEC sp_rename N'[dbo].[t].[a]', N'b', N'COLUMN';")
        #expect(ColumnRenameStatement.sql(table: "\"public\".\"t\"", oldName: "a", newName: "b", databaseType: .postgresql)
                == "ALTER TABLE \"public\".\"t\" RENAME COLUMN \"a\" TO \"b\";")
    }
}
