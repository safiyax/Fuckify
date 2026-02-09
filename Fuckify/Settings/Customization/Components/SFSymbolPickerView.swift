//
//  CustomItemEditorView.swift
//  Fuckify
//
//  Shared components for custom item editing
//

import SwiftUI
import Dependencies

// MARK: - SF Symbol Picker

/// Curated list of relevant SF Symbols for activities, protection methods, and partner attributes
private let curatedSymbols = [
    // General
    "heart.fill", "star.fill", "circle.fill", "square.fill", "triangle.fill",
    "person.text.rectangle", "person.crop.circle", "heart.text.square",
    // Body/People
    "figure.2", "figure.arms.open", "hands.and.sparkles.fill", "hand.raised.fill",
    "mouth", "face.smiling", "face.dashed.fill",
    // Actions
    "bolt.fill", "flame.fill", "drop.fill", "leaf.fill", "moon.stars.fill",
    // Medical/Health
    "pills.fill", "cross.fill", "bandage.fill", "medical.thermometer.fill",
    "pills.circle.fill", "stethoscope", "syringe", "medical.thermometer",
    "calendar.badge.clock",
    // Protection
    "shield.fill", "lock.fill", "checkmark.shield.fill", "exclamationmark.shield.fill",
    // Dates/Time
    "calendar", "clock", "hourglass", "timer",
    // Status/Info
    "info.circle", "checkmark.circle", "xmark.circle", "exclamationmark.circle",
    "flag.fill", "bookmark.fill",
    // Communication
    "phone.fill", "message.fill", "envelope.fill",
    // Relationships
    "heart.circle", "sparkles",
    // Other
    "wand.and.stars", "arrow.uturn.backward",
    "ellipsis.circle", "questionmark.circle.fill", "plus.circle.fill",
    "globe", "house.fill", "briefcase.fill", "graduationcap.fill",
    "guidepoint.vertical.numbers"
]

struct SFSymbolPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    
    let columns = [
        GridItem(.adaptive(minimum: 60))
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(curatedSymbols, id: \.self) { symbol in
                        Button {
                            selectedIcon = symbol
                            dismiss()
                        } label: {
                            VStack {
                                Image(systemName: symbol)
                                    .font(.largeTitle)
                                    .foregroundColor(selectedIcon == symbol ? .accentColor : .primary)
                                    .frame(width: 60, height: 60)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIcon == symbol ? Color.accentColor.opacity(0.1) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedIcon == symbol ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                                    )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Legacy Views Removed
// Note: AddActivityView, EditActivityView, AddProtectionMethodView, and EditProtectionMethodView
// have been moved to their own unified form files:
// - ActivityFormView.swift
// - ProtectionMethodFormView.swift
//
// This file now only contains SFSymbolPickerView which is shared by all form views.
