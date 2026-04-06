//
//  PartnerAttributesSettingsView.swift
//  Fuckify
//
//  Settings view for managing custom partner attributes
//

import SwiftUI
import Dependencies

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "PartnerAttributesSettings")

struct PartnerAttributesSettingsView: View {
    @Dependency(\.partnerAttributeService) private var attributeService
    
    @State private var attributes: [SQLPartnerAttributeType] = []
    @State private var showingAddAttribute = false
    @State private var errorMessage: String?
    @State private var attributeToDelete: SQLPartnerAttributeType?
    @State private var showingDeleteAlert = false
    @State private var attributeToEdit: SQLPartnerAttributeType?
    
    private let accentColor = Color.accentColor
    
    var builtInAttributes: [SQLPartnerAttributeType] {
        attributes.filter { $0.isBuiltIn }
    }
    
    var customAttributes: [SQLPartnerAttributeType] {
        attributes.filter { !$0.isBuiltIn }
    }
    
    var body: some View {
        List {
            Section {
                Text("Manage custom fields for partner profiles. Built-in fields can be enabled/disabled. Custom fields can be edited or deleted.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Built-in Attributes
            if !builtInAttributes.isEmpty {
                Section("Built-in Attributes") {
                    ForEach(builtInAttributes) { attribute in
                        AttributeRow(
                            attribute: attribute,
                            onToggle: { toggleAttribute(attribute) }
                        )
                    }
                }
            }
            
            // Custom Attributes
            Section {
                ForEach(customAttributes) { attribute in
                    AttributeRow(
                        attribute: attribute,
                        onToggle: { toggleAttribute(attribute) }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            attributeToDelete = attribute
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                        
                        Button {
                            attributeToEdit = attribute
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                
                Button {
                    showingAddAttribute = true
                } label: {
                    Label("Add Custom Attribute", systemImage: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            } header: {
                Text("Custom Attributes")
            } footer: {
                if customAttributes.isEmpty {
                    Text("Tap + to add your own custom fields for partners")
                        .font(.caption)
                }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .tint(accentColor)
        .navigationTitle("Partner Attributes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddAttribute = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddAttribute) {
            PartnerAttributeFormView {
                loadAttributes()
            }
            .tint(accentColor)
        }
        .sheet(item: $attributeToEdit) { attribute in
            PartnerAttributeFormView(attribute: attribute) {
                loadAttributes()
            }
            .tint(accentColor)
        }
        .alert("Delete Attribute", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let attribute = attributeToDelete {
                    deleteAttribute(attribute)
                }
            }
        } message: {
            Text("Are you sure you want to delete this custom attribute? All values for this attribute will be removed from partners.")
        }
        .task {
            loadAttributes()
        }
    }
    
    private func loadAttributes() {
        do {
            attributes = try attributeService.fetchAllAttributeTypes()
        } catch {
            errorMessage = "Failed to load attributes: \(error.localizedDescription)"
        }
    }
    
    private func toggleAttribute(_ attribute: SQLPartnerAttributeType) {
        do {
            try attributeService.toggleAttributeType(id: attribute.id)
            loadAttributes()
        } catch {
            logger.error("Failed to toggle attribute \(attribute.id): \(error.localizedDescription)")
            errorMessage = "Failed to update attribute: \(error.localizedDescription)"
        }
    }
    
    private func deleteAttribute(_ attribute: SQLPartnerAttributeType) {
        do {
            logger.info("Deleting partner attribute: \(attribute.id)")
            try attributeService.deleteAttributeType(id: attribute.id)
            loadAttributes()
        } catch {
            logger.error("Failed to delete attribute \(attribute.id): \(error.localizedDescription)")
            errorMessage = "Failed to delete attribute: \(error.localizedDescription)"
        }
    }
    

}

// MARK: - Attribute Row

struct AttributeRow: View {
    let attribute: SQLPartnerAttributeType
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: attribute.icon)
                .font(.title3)
                .foregroundColor(attribute.isEnabled ? .accentColor : .gray)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(attribute.name)
                    .font(.body)
                    .foregroundColor(attribute.isEnabled ? .primary : .secondary)
                
                HStack(spacing: 4) {
                    if attribute.isBuiltIn {
                        Text("Built-in")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Text(attribute.parsedFieldType.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { attribute.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .accessibilityLabel("\(attribute.name) enabled")
        }
        .padding(.vertical, 0)
    }
}

#Preview {
    NavigationStack {
//        PartnerAttributesSettingsView()
    }
}
