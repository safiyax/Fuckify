//
//  CustomItemEditorView.swift
//  Fuckify
//
//  Shared components for custom item editing
//

import SwiftUI
import Dependencies
import SFSafeSymbols

// MARK: - SF Symbol Picker

/// Curated list of relevant SF Symbols for activities, protection methods, and partner attributes
private let curatedSymbols: [SFSymbol] = [
    // Hearts & Romance
    .heartFill, .heartCircle, .heartCircleFill, .heartTextSquare,
    .heartSlashFill, .suitHeartFill,

    // People & Bodies
    .personFill, .person2Fill, .personCropCircle, .personCropCircleFill,
    .personTextRectangle, .figure2, .figureArmsOpen,
    .figureWalk, .figureStand, .figure2ArmsOpen,

    // Hands & Touch
    .handRaisedFill, .handsAndSparklesFill, .handThumbsupFill,
    .handThumbsdownFill, .handPointUpLeftFill, .handWave,

    // Face & Expressions
    .mouth, .faceSmiling, .faceSmilingInverse, .faceDashedFill,
    .eyeFill, .eye, .eyeSlashFill,

    // Activities & Energy
    .boltFill, .bolt, .flameFill, .flame,
    .dropFill, .drop, .leafFill, .leaf,
    .moonStarsFill, .moonFill, .sunMaxFill, .sparkles,
    .starFill, .star,

    // Positions & Movement
    .arrowUpCircleFill, .arrowDownCircleFill, .arrowUpArrowDownCircleFill,
    .arrowLeftArrowRightCircleFill,
    .rotate3d, .rotateLeft, .rotateRight,

    // Medical & Health
    .pillsFill, .pillsCircleFill, .crossFill, .crossCircleFill,
    .bandageFill, .staroflifeFill, .staroflife,
    .stethoscope, .syringe, .medicalThermometer, .medicalThermometerFill,
    .waveformPathEcg,

    // Protection & Safety
    .shieldFill, .shield, .lockFill, .lock,
    .checkmarkShieldFill, .exclamationmarkShieldFill,
    .keyFill, .key,

    // Calendar & Time
    .calendar, .calendarBadgeClock, .calendarCircleFill,
    .clock, .clockFill, .hourglass, .timer,
    .alarmFill, .stopwatchFill,

    // Location & Places
    .locationFill, .location, .mapFill, .map,
    .houseFill, .house, .buildingFill, .building2Fill,
    .carFill,

    // Status & Ratings
    .checkmarkCircleFill, .checkmarkCircle, .xmarkCircleFill, .xmarkCircle,
    .exclamationmarkCircleFill, .exclamationmarkCircle,
    .flagFill, .flag, .bookmarkFill, .bookmark,
    .tagFill, .tag, .sealFill,

    // Communication
    .phoneFill, .messageFill, .envelopeFill,
    .bubbleLeftFill, .bubbleRightFill, .bubbleLeftAndBubbleRightFill,

    // Emotions & Moods
    .moonZzzFill, .zzz,

    // Misc / Customization
    .wandAndSparkles,
    .circleFill, .circle, .squareFill, .triangleFill,
    .ellipsisCircle, .questionmarkCircleFill, .plusCircleFill,
    .minusCircle, .infoCircle,
    .globe, .briefcaseFill, .graduationcapFill,
    .musicNote, .musicMicrophone, .wineglass,
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
                    ForEach(curatedSymbols, id: \.rawValue) { symbol in
                        Button {
                            selectedIcon = symbol.rawValue
                            dismiss()
                        } label: {
                            Image(systemSymbol: symbol)
                                .font(.largeTitle)
                                .foregroundColor(selectedIcon == symbol.rawValue ? .accentColor : .primary)
                                .frame(width: 60, height: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedIcon == symbol.rawValue ? Color.accentColor.opacity(0.1) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedIcon == symbol.rawValue ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                                )
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
