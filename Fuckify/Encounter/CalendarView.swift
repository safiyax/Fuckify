//
//  CalendarView.swift
//  Fuckify
//
//  Calendar view with month grid and encounter list
//  Matches iOS Calendar app split mode design
//

import SwiftUI
import SQLiteData
import Dependencies

struct CalendarView: View {
    @FetchAll private var encounters: [SQLEncounter]
    @FetchAll private var partners: [SQLPartner]
    @Dependency(\.encounterService) var encounterService
    private let config = EncountersConfig.shared
    
    @State private var selectedDate: Date = Date()
    @State private var displayedMonth: Date = Date()
    @State private var encountersByDate: [Date: [SQLEncounter]] = [:]
    @State private var partnerColorsByDate: [Date: [Color]] = [:]
    @State private var showingAddEncounter = false
    @State private var encounterToEdit: SQLEncounter?
    @State private var encounterToDelete: SQLEncounter?
    @State private var showingDeleteAlert = false
    @State private var refreshTrigger = false
    @State private var isInitialLoad = true
    @State private var showContent = false
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                calendarSection
            }
            .opacity(showContent ? 1 : 0)
            .padding(.top, -6)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingAddEncounter) {
                EncounterFormView(preselectedDate: selectedDate)
            }
            .sheet(item: $encounterToEdit) { encounter in
                EncounterFormView(encounter: encounter)
                    .onDisappear {
                        // Sheet was dismissed, trigger refresh with animation
                        withAnimation(.easeInOut(duration: 0.3)) {
                            refreshTrigger.toggle()
                        }
                    }
            }
            .alert("Delete Encounter", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let encounter = encounterToDelete {
                        deleteEncounter(encounter)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this encounter? This action cannot be undone.")
            }
            .task {
                await loadEncountersAnimated()
            }
            .onChange(of: encounters.count) { _, _ in
                Task {
                    await loadEncountersAnimated()
                }
            }
            .onChange(of: refreshTrigger) { _, _ in
                Task {
                    await loadEncounters()  // Don't toggle again, just reload
                }
            }
        }
    }
    
    private var calendarSection: some View {
        VStack(spacing: 0) {
            calendarHeader(displayedMonth)
            weekdayHeaders
            AdjustableDivider(height: 1.5)
            
            monthDayGrid(for: displayedMonth)
                .gesture(
                    DragGesture(minimumDistance: 50)
                        .onEnded { value in
                            let verticalMovement = value.translation.height
                            
                            // Swipe down = previous month
                            // Swipe up = next month
                            if verticalMovement > 0 {
                                previousMonth()
                            } else if verticalMovement < 0 {
                                nextMonth()
                            }
                        }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            
            AdjustableDivider(fill: .secondary.opacity(0.1))
            
            encountersListSection()
        }
        .padding(.bottom, 0)
        .background(Color(.systemBackground))
    }
    
//    @
    
    @ViewBuilder
    private func calendarHeader(_ month: Date) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(month.formatted(.dateTime.month(.wide)))
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal)
            Spacer()
            
            HStack {
                Button {
                    previousMonth()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }
                Text(month.formatted(.dateTime.year(.defaultDigits)))
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                //                .padding(.horizontal)
                Button {
                    nextMonth()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                }
            }
            .padding(.trailing)
        }
        .padding(.top, 12)
    }
    
    private func monthDayGrid(for month: Date) -> some View {
        let days = daysInMonth(for: month)
        
        return VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { weekIndex in
                weekContent(for: weekIndex, days: days, month: month)
            }
        }
    }
    
    private var weekdayHeaders: some View {
        HStack(spacing: 0) {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                Text(day.prefix(1))
                    .font(.system(size: 10))
                    .fontWeight(.semibold)
                    .foregroundColor(weekdayHeaderTextColor(day))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 2)
        .padding(.top, 10)
    }
    
    private func weekdayHeaderTextColor(_ day: String) -> Color {
        if day.prefix(3) == "Sat" || day.prefix(3) == "Sun" {
            return .secondary
        }
        return .primary
    }
    
    @ViewBuilder
    private func weekContent(for weekIndex: Int, days: [Date], month: Date) -> some View {
        if weekHasCurrentMonthDays(weekIndex, days: days, month: month) {
            weekRow(for: weekIndex, days: days, month: month)
            
            if weekIndex < 5 && weekHasCurrentMonthDays(weekIndex + 1, days: days, month: month) {
                AdjustableDivider(height: 1)
            }
        }
    }
    
    private func weekRow(for weekIndex: Int, days: [Date], month: Date) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { dayIndex in
                let dateIndex = weekIndex * 7 + dayIndex
                if dateIndex < days.count {
                    let date = days[dateIndex]
                    CalendarDayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        isWeekend: dayIndex == 0 || dayIndex == 6,
                        isCurrentMonth: calendar.isDate(date, equalTo: month, toGranularity: .month),
                        partnerColors: partnerColors(for: date),
                        encounterCount: encounterCount(for: date)
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDate = date
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 5)
        .padding(.bottom, 0)
    }
    
    private func weekHasCurrentMonthDays(_ weekIndex: Int, days: [Date], month: Date) -> Bool {
        let weekDates = (0..<7).compactMap { dayIndex -> Date? in
            let dateIndex = weekIndex * 7 + dayIndex
            return dateIndex < days.count ? days[dateIndex] : nil
        }
        
        return weekDates.contains { date in
            calendar.isDate(date, equalTo: month, toGranularity: .month)
        }
    }
    
    @ViewBuilder
    private func encountersListSection() -> some View {
        if encountersForSelectedDate.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(encountersForSelectedDate) { encounter in
                        NavigationLink {
                            EncounterDetailView(encounter: encounter)
                        } label: {
                            CalendarEncounterRow(encounter: encounter)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                encounterToEdit = encounter
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                encounterToDelete = encounter
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .id(refreshTrigger)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
//            .background(Color(.systemGroupedBackground))
        }
    }
    
    private var emptyStateView: some View {
        
        ContentUnavailableView("No Activity", systemImage: "calendar.badge.exclamationmark")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(action: { showingAddEncounter = true }) {
                Label("Add Encounter", systemImage: "plus")
            }
        }
        
        ToolbarItem(placement: .topBarLeading) {
            Button {
                withAnimation {
                    selectedDate = Date()
                    displayedMonth = Date()
                }
            } label: {
                Text("Today")
                    .fontWeight(.medium)
            }
        }
        
        ToolbarItem(placement: .bottomBar) {
            Spacer()
        }
        
        if config.showInvitesItem {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    
                    ContentUnavailableView("Under Construction", systemImage: "hourglass")
                        .navigationTitle("Invitations")
                        .navigationBarTitleDisplayMode(.large)
                    
                } label: {
                    Label("Invitations", systemImage: "tray")
                }
                
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private func daysInMonth(for month: Date) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        
        var dates: [Date] = []
        var date = monthFirstWeek.start
        
        // Generate 6 weeks (42 days) to ensure complete grid
        for _ in 0..<42 {
            dates.append(date)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = nextDate
        }
        
        return dates
    }
    
    private var encountersForSelectedDate: [SQLEncounter] {
        let startOfDay = calendar.startOfDay(for: selectedDate)
        return encountersByDate[startOfDay] ?? []
    }
    
    // MARK: - Helper Methods
    
    private func partnerColors(for date: Date) -> [Color] {
        let startOfDay = calendar.startOfDay(for: date)
        return partnerColorsByDate[startOfDay] ?? []
    }
    
    private func encounterCount(for date: Date) -> Int {
        let startOfDay = calendar.startOfDay(for: date)
        return encountersByDate[startOfDay]?.count ?? 0
    }
    
    private func previousMonth() {
        guard let newDate = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            displayedMonth = newDate
            // If new month is current month, select today; otherwise select 1st
            if calendar.isDate(newDate, equalTo: Date(), toGranularity: .month) {
                selectedDate = Date()
            } else {
                selectedDate = calendar.date(from: calendar.dateComponents([.year, .month], from: newDate)) ?? newDate
            }
        }
    }
    
    private func nextMonth() {
        guard let newDate = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            displayedMonth = newDate
            // If new month is current month, select today; otherwise select 1st
            if calendar.isDate(newDate, equalTo: Date(), toGranularity: .month) {
                selectedDate = Date()
            } else {
                selectedDate = calendar.date(from: calendar.dateComponents([.year, .month], from: newDate)) ?? newDate
            }
        }
    }
    
    private func deleteEncounter(_ encounter: SQLEncounter) {
        Task {
            do {
                try encounterService.delete(encounter.id)
                await loadEncounters()
            } catch {
                print("Failed to delete encounter: \(error)")
            }
        }
    }
    
    @MainActor
    private func loadEncountersAnimated() async {
        if isInitialLoad {
            // First load - load data then animate in
            await loadEncounters()
            isInitialLoad = false
            
            // Small delay to ensure view is laid out
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            withAnimation(.easeInOut(duration: 0.4)) {
                showContent = true
                refreshTrigger.toggle()
            }
        } else {
            // Subsequent loads
            await loadEncounters()
            withAnimation(.easeInOut(duration: 0.3)) {
                refreshTrigger.toggle()
            }
        }
    }
    
    @MainActor
    private func loadEncounters() async {
        var grouped: [Date: [SQLEncounter]] = [:]
        var colorsByDate: [Date: [Color]] = [:]
        
        for encounter in encounters {
            guard let date = encounter.date else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            grouped[startOfDay, default: []].append(encounter)
        }
        
        // Now build color array based on unique partners across ALL encounters on that day
        for (date, dayEncounters) in grouped {
            var allPartnerColors: [Color] = []
            var seenPartnerIDs: Set<UUID> = []
            
            // Go through each encounter on this day
            for encounter in dayEncounters {
                do {
                    let encounterPartners = try encounterService.fetchPartners(for: encounter.id)
                    for partner in encounterPartners {
                        // Only add each unique partner once (by ID), but we still show pill if multiple encounters
                        if !seenPartnerIDs.contains(partner.id) {
                            seenPartnerIDs.insert(partner.id)
                            allPartnerColors.append(Color.fromPartnerColorName(partner.avatarColor))
                        }
                    }
                } catch {
                    // Silent fail
                }
            }
            
            colorsByDate[date] = allPartnerColors
        }
        
        // Sort encounters within each day by time (most recent first)
        for (date, encounters) in grouped {
            grouped[date] = encounters.sorted { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }
        }
        
        encountersByDate = grouped
        partnerColorsByDate = colorsByDate
    }
}

// MARK: - Calendar Day Cell

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
        } else {
            // Empty space for non-current-month days
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 29)
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
}

// MARK: - Calendar Encounter Row

struct CalendarEncounterRow: View {
    let encounter: SQLEncounter
    
    @Dependency(\.encounterService) var encounterService
    @State private var partners: [SQLPartner] = []
    @State private var activities: [SQLActivityType] = []
    @State private var protectionMethods: [SQLProtectionMethod] = []
    
    var body: some View {
        HStack(spacing: 12) {
            // Time indicator (colored bar with partner colors)
            partnerColorBar
            
            VStack(alignment: .leading, spacing: 4) {
                // Time
//                if let date = encounter.date {
//                    Text(date.formatted(date: .omitted, time: .shortened))
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                }
                HStack(spacing: 8) {
                    // Partners
                    if !partners.isEmpty {
                        Text(partners.map(\.name).joined(separator: ", "))
                            .font(.headline)
                            .foregroundColor(.primary)
                    } else {
                        Text("No partners")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if encounter.duration > 0 {
                        Text("\(encounter.formattedDuration)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Activities and Duration
                HStack(spacing: 8) {
                    if !activities.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(activities.prefix(4), id: \.self) { activity in
                                Image(systemName: activity.icon)
                                    .font(.subheadline)
                                    .foregroundColor(.purple)
                            }
                            if activities.count > 4 {
                                Text("+\(activities.count - 4)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                    if !protectionMethods.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(protectionMethods, id: \.self) { protectionMethod in
                                Image(systemName: protectionMethod.icon)
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .task {
            await loadData()
        }
    }
    
    @ViewBuilder
    private var partnerColorBar: some View {
        let partnerColors = partners.map { Color.fromPartnerColorName($0.avatarColor) }
        
        if partnerColors.isEmpty {
            // Fallback to accent color if no partners
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor)
                .frame(width: 4)
        } else if partnerColors.count == 1 {
            // Single partner - solid color
            RoundedRectangle(cornerRadius: 8)
                .fill(partnerColors[0])
                .frame(width: 4)
        } else {
            // Multiple partners - split vertically
            VStack(spacing: 0) {
                ForEach(0..<partnerColors.count, id: \.self) { index in
                    partnerColors[index]
                }
            }
            .frame(width: 4)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    @MainActor
    private func loadData() async {
        do {
            partners = try encounterService.fetchPartners(for: encounter.id)
            activities = try encounterService
                .fetchActivities(for: encounter.id)
                .sorted { $0.displayName < $1.displayName }
            protectionMethods = try encounterService
                .fetchProtectionMethods(for: encounter.id)
                .sorted { $0.displayName < $1.displayName }
        } catch {
            // Silent fail
        }
    }
}

struct AdjustableDivider: View {
    var fill: Color = Color(uiColor: .separator)
    var height: CGFloat = 1
    
    var body: some View {
        Rectangle()
            .fill(fill)
            .frame(height: height)
    }
}

// MARK: - Preview

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }
    
    return CalendarView()
}
