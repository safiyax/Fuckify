//
//  CalendarDayCell.swift
//  Fuckify
//
//  Individual day cell for calendar grid
//

import SwiftUI

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isWeekend: Bool
    let isCurrentMonth: Bool
    let partnerColors: [Color]
    let encounterCount: Int
    
    private let calendar = Calendar.current
    
    var body: some View {
        if isCurrentMonth {
            VStack(spacing: 0) {
                ZStack {
                    // Selected background circle
                    if isSelected {
                        Circle()
                            .fill(circleColor)
                    }
                    // Day number
                    Text("\(calendar.component(.day, from: date))")
                        .font(textFont)
                        .foregroundColor(textColor)
                }
                .frame(width: 29, height: 29)
                
                // Partner color indicators
                partnerIndicator
                    .padding(.top, 3)
                    .padding(.bottom, 7)
                
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
            .accessibilityHint(encounterCount > 0 ? "Double tap to view encounters" : "Double tap to add encounter")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            // Empty space for non-current-month days
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 29)
                .accessibilityHidden(true)
        }
    }
    
    @ViewBuilder
    private var partnerIndicator: some View {
        let dotSize: CGFloat = 6
        let colorCount = min(partnerColors.count, 6)
        let pillWidth = dotSize * CGFloat(colorCount) // Width grows with number of colors
        let altPillWidth = dotSize * CGFloat(min(encounterCount, 6))
        
        if partnerColors.isEmpty || encounterCount == 0 {
            Color.clear.frame(height: dotSize)
        } else if encounterCount == 1 && partnerColors.count == 1 {
            // Single encounter, single partner - show dot
            Circle()
                .fill(partnerColors[0])
                .frame(width: dotSize, height: dotSize)
        } else if encounterCount > 1 && partnerColors.count == 1 {
            HStack(spacing: 0) {
                ForEach(0..<min(encounterCount, 6), id: \.self) { index in
                    partnerColors[0]
                }
            }
            .frame(width: altPillWidth, height: dotSize)
            .clipShape(Capsule())
        } else {
            // Multiple encounters OR multiple partners - show pill with color segments
            HStack(spacing: 0) {
                ForEach(0..<colorCount, id: \.self) { index in
                    partnerColors[index]
                }
            }
            .frame(width: pillWidth, height: dotSize)
            .clipShape(Capsule())
        }
    }
    
    private var circleColor: Color {
        if isSelected && isToday {
            return .accentColor
        } else {
            return .init(uiColor: .label)
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .init(uiColor: .systemBackground)
        } else if isToday && isSelected{
            return .primary
        } else if isToday {
            return .accentColor
        } else if !isCurrentMonth {
            return .secondary.opacity(0.5)
        } else if isWeekend {
            return .secondary
        } else {
            return .primary
        }
    }
    
    private var textFont: Font {
        if isSelected || isToday {
            return .system(size: 18, weight: .bold)
        }
        return .system(size: 18, weight: .semibold)
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d"
        var label = dateFormatter.string(from: date)
        
        if isToday {
            label += ", today"
        }
        
        return label
    }
    
    private var accessibilityValue: String {
        if encounterCount == 0 {
            return "No encounters"
        } else if encounterCount == 1 {
            if partnerColors.count == 1 {
                return "1 encounter with 1 partner"
            } else {
                return "1 encounter with \(partnerColors.count) partners"
            }
        } else {
            return "\(encounterCount) encounters with \(partnerColors.count) \(partnerColors.count == 1 ? "partner" : "partners")"
        }
    }
}

#Preview {
    VStack {
        CalendarDayCell(
            date: Date(),
            isSelected: false,
            isToday: true,
            isWeekend: false,
            isCurrentMonth: true,
            partnerColors: [.blue, .red],
            encounterCount: 2
        )
        
        CalendarDayCell(
            date: Date(),
            isSelected: true,
            isToday: false,
            isWeekend: false,
            isCurrentMonth: true,
            partnerColors: [],
            encounterCount: 0
        )
    }
    .padding()
}
