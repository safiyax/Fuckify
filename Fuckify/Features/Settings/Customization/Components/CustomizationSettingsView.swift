import SwiftUI

protocol CustomizableItem: Identifiable where ID == UUID {
    nonisolated var id: UUID { get }
    var icon: String { get }
    var name: String { get }
    var isEnabled: Bool { get }
    var isBuiltIn: Bool { get }
}

struct CustomizationSettingsView<
    Item: CustomizableItem,
    AddSheet: View,
    EditSheet: View,
    RowContent: View,
    AdditionalSections: View
>: View {
    let navigationTitle: String
    let itemTypeName: String
    let descriptionText: String
    let accentColor: Color
    let items: [Item]
    let emptyCustomFooterText: String?
    let deleteConfirmationMessage: String?

    let onToggle: (Item) -> Void
    let onDelete: (Item) -> Void

    @ViewBuilder let addSheet: () -> AddSheet
    @ViewBuilder let editSheet: (Item) -> EditSheet
    @ViewBuilder let itemRow: (Item, @escaping () -> Void) -> RowContent
    @ViewBuilder let additionalSections: () -> AdditionalSections

    @State private var showingAdd = false
    @State private var itemToEdit: Item?
    @State private var itemToDelete: Item?
    @State private var showingDeleteAlert = false

    private var builtInItems: [Item] { items.filter { $0.isBuiltIn } }
    private var customItems: [Item] { items.filter { !$0.isBuiltIn } }

    var body: some View {
        List {
            Section {
                Text(descriptionText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if !builtInItems.isEmpty {
                Section("Built-in \(navigationTitle)") {
                    ForEach(builtInItems) { item in
                        itemRow(item, { onToggle(item) })
                    }
                }
            }

            Section {
                ForEach(customItems) { item in
                    itemRow(item, { onToggle(item) })
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                itemToDelete = item
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)

                            Button {
                                itemToEdit = item
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }

                Button {
                    showingAdd = true
                } label: {
                    Label("Add Custom \(itemTypeName)", systemImage: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            } header: {
                Text("Custom \(navigationTitle)")
            } footer: {
                if customItems.isEmpty {
                    Text(emptyCustomFooterText ?? "Tap + to add your own custom \(navigationTitle.lowercased())")
                        .font(.caption)
                }
            }

            additionalSections()
        }
        .tint(accentColor)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            addSheet()
                .tint(accentColor)
        }
        .sheet(item: $itemToEdit) { item in
            editSheet(item)
                .tint(accentColor)
        }
        .alert("Delete \(itemTypeName)", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    onDelete(item)
                }
            }
        } message: {
            Text(deleteConfirmationMessage ?? "Are you sure you want to delete this custom \(itemTypeName.lowercased())?")
        }
    }
}

extension CustomizationSettingsView where AdditionalSections == EmptyView {
    init(
        navigationTitle: String,
        itemTypeName: String,
        descriptionText: String,
        accentColor: Color,
        items: [Item],
        emptyCustomFooterText: String? = nil,
        deleteConfirmationMessage: String? = nil,
        onToggle: @escaping (Item) -> Void,
        onDelete: @escaping (Item) -> Void,
        @ViewBuilder addSheet: @escaping () -> AddSheet,
        @ViewBuilder editSheet: @escaping (Item) -> EditSheet,
        @ViewBuilder itemRow: @escaping (Item, @escaping () -> Void) -> RowContent
    ) {
        self.navigationTitle = navigationTitle
        self.itemTypeName = itemTypeName
        self.descriptionText = descriptionText
        self.accentColor = accentColor
        self.items = items
        self.emptyCustomFooterText = emptyCustomFooterText
        self.deleteConfirmationMessage = deleteConfirmationMessage
        self.onToggle = onToggle
        self.onDelete = onDelete
        self.addSheet = addSheet
        self.editSheet = editSheet
        self.itemRow = itemRow
        self.additionalSections = { EmptyView() }
    }
}
