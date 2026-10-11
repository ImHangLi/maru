import SwiftUI

/// The add button at the top right of both tabs (D020).
struct AddItemButton: ToolbarContent {
    @Environment(AppModel.self) private var model

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Add Item", systemImage: "plus") { model.openEditor(for: nil) }
        }
    }
}
