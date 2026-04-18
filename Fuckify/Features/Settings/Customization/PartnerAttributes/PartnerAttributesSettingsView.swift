//
//  PartnerAttributesSettingsView.swift
//  Fuckify
//
//  Settings view for managing custom partner attributes
//

import SwiftUI
import Dependencies

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "PartnerAttributesSettings")

extension SQLPartnerAttributeType: CustomizableItem {}

struct PartnerAttributesSettingsView: View {
    @Dependency(\.partnerAttributeService) private var attributeService
    
    @State private var attributes: [SQLPartnerAttributeType] = []
    @State private var errorMessage: String?
    
    private let accentColor = Color.accentColor
    
    var body: some View {
        CustomizationSettingsView(
            navigationTitle: "Partner Attributes",
            itemTypeName: "Attribute",
            descriptionText: "Manage custom fields for partner profiles. Built-in fields can be enabled/disabled. Custom fields can be edited or deleted.",
            accentColor: accentColor,
            items: attributes,
            emptyCustomFooterText: "Tap + to add your own custom fields for partners",
            deleteConfirmationMessage: "Are you sure you want to delete this custom attribute? All values for this attribute will be removed from partners.",
            onToggle: toggleAttribute,
            onDelete: deleteAttribute,
            addSheet: {
                PartnerAttributeFormView(onSave: loadAttributes)
            },
            editSheet: { attribute in
                PartnerAttributeFormView(attribute: attribute, onSave: loadAttributes)
            },
            itemRow: { attribute, toggleAction in
                AttributeRow(attribute: attribute, onToggle: toggleAction)
            },
            additionalSections: {
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
        )
        .task { loadAttributes() }
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

private struct AttributeRow: View {
    let attribute: SQLPartnerAttributeType
    let onToggle: () -> Void

    var body: some View {
        CustomizationItemRow(
            icon: attribute.icon,
            name: attribute.name,
            isEnabled: attribute.isEnabled,
            isBuiltIn: attribute.isBuiltIn,
            accentColor: .accentColor,
            extraBadge: attribute.parsedFieldType.displayName,
            extraBadgeColor: .purple,
            onToggle: onToggle
        )
    }
}

#Preview {
    NavigationStack {
//        PartnerAttributesSettingsView()
    }
}
