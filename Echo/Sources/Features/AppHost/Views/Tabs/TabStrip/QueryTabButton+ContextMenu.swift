import SwiftUI

/// The tab's menu (TABS-2.12): pin, duplicate, switch database, the closes, and for a query tab
/// its home's commands.
extension QueryTabButton {
    var tabContextMenuContent: some View {
        Group {
            Button(action: onPinToggle) {
                Label(tab.isPinned ? "Unpin Tab" : "Pin Tab", systemImage: tab.isPinned ? "pin.slash" : "pin")
            }

            Button(action: onDuplicate) {
                Label("Duplicate Tab", systemImage: "plus.square.on.square")
            }
            .disabled(!canDuplicate)

            if !availableDatabases.isEmpty, let onSwitchDatabase {
                Divider()
                Menu {
                    ForEach(availableDatabases, id: \.self) { dbName in
                        Button {
                            onSwitchDatabase(dbName)
                        } label: {
                            if dbName == tab.activeDatabaseName {
                                Label(dbName, systemImage: "checkmark")
                            } else {
                                Text(dbName)
                            }
                        }
                    }
                } label: {
                    Label("Switch Database", systemImage: "cylinder")
                }
            }

            Divider()

            Button(action: onClose) {
                Label("Close Tab", systemImage: "xmark")
            }

            Button(action: onCloseOthers) {
                Label("Close Other Tabs", systemImage: "xmark.square")
            }
            .disabled(closeOthersDisabled)

            Button(action: onCloseLeft) {
                Label("Close Tabs to the Left", systemImage: "arrow.left.to.line")
            }
            .disabled(closeTabsLeftDisabled)

            Button(action: onCloseRight) {
                Label("Close Tabs to the Right", systemImage: "arrow.right.to.line")
            }
            .disabled(closeTabsRightDisabled)

            if tab.query != nil {
                Divider()
                homeMenuContent
            }
        }
    }
}
