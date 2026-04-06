//
//  DebugFlagRow.swift
//  Fuckify
//
//  Reusable row component for displaying feature flags in debug views
//

import SwiftUI

struct DebugFlagRow: View {
    let label: String
    @Binding var value: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(value ? .green : .red)
                .font(.body)
            
            Text(label)
            
            Spacer()
            
            Toggle("", isOn: $value)
                .labelsHidden()
        }
    }
}
