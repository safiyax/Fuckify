//
//  ProtectionMethodsSelectionSection.swift
//  Fuckify
//
//  Reusable protection methods selection section for encounter forms
//

import SwiftUI
import SQLiteData

struct ProtectionMethodsSelectionSection: View {
    let availableProtectionMethods: [SQLProtectionMethodEntity]
    @Binding var selectedProtectionIDs: Set<UUID>
    
    var body: some View {
        Section("Protection") {
            ForEach(availableProtectionMethods.filter { $0.isEnabled }) { protection in
                Button(action: { toggleProtection(protection.id) }) {
                    HStack {
                        Image(systemName: protection.icon)
                            .foregroundColor(.green)
                            .accessibilityHidden(true)
                        Text(protection.name)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedProtectionIDs.contains(protection.id) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityLabel(protection.name)
                .accessibilityAddTraits(selectedProtectionIDs.contains(protection.id) ? .isSelected : [])
                .accessibilityHint("Double tap to \(selectedProtectionIDs.contains(protection.id) ? "deselect" : "select") this protection method")
            }
        }
    }
    
    private func toggleProtection(_ protectionID: UUID) {
        if selectedProtectionIDs.contains(protectionID) {
            selectedProtectionIDs.remove(protectionID)
        } else {
            selectedProtectionIDs.insert(protectionID)
        }
    }
}

#Preview {
    let methods = [
        SQLProtectionMethodEntity(id: UUID(), name: "Condom", icon: "shield.fill", isBuiltIn: true),
        SQLProtectionMethodEntity(id: UUID(), name: "PrEP", icon: "pills.fill", isBuiltIn: true)
    ]
    
    return Form {
        ProtectionMethodsSelectionSection(
            availableProtectionMethods: methods,
            selectedProtectionIDs: .constant([methods[0].id])
        )
    }
}
