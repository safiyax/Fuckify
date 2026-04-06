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

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "CalendarView")

/// Sheet presentation mode for encounter form
enum EncounterFormMode: Identifiable {
    case add(preselectedDate: Date)
    case edit(encounter: SQLEncounter)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let encounter): return "edit-\(encounter.id)"
        }
    }
}

struct CalendarView: View {
    @FetchAll private var encounters: [SQLEncounter]
    @FetchAll private var partners: [SQLPartner]
    @Dependency(\.encounterService) var encounterService
    private let config = EncountersConfig.shared
    
    @State private var selectedDate: Date = Date()
    @State private var displayedMonth: Date = Date()
    @State private var encountersByDate: [Date: [SQLEncounter]] = [:]
    @State private var partnerColorsByDate: [Date: [Color]] = [:]
    @State private var encounterFormMode: EncounterFormMode?
    @State private var encounterToDelete: SQLEncounter?
    @State private var showingDeleteAlert = false
    @State private var refreshTrigger = false
    @State private var isInitialLoad = true
    @State private var showContent = false
    @State private var showingLiveActivityStart = false
    
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
            .sheet(item: $encounterFormMode) { mode in
                switch mode {
                case .add(let preselectedDate):
                    EncounterFormView(preselectedDate: preselectedDate)
                case .edit(let encounter):
                    EncounterFormView(encounter: encounter)
                        .onDisappear {
                            // Sheet was dismissed, trigger refresh with animation
                            withAnimation(.easeInOut(duration: 0.3)) {
                                refreshTrigger.toggle()
                            }
                        }
                }
            }
            .sheet(isPresented: $showingLiveActivityStart) {
                LiveActivityPartnerSelector()
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
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("editEncounter"))) { notification in
                logger.info("Received editEncounter notification")
                if let encounter = notification.userInfo?["encounter"] as? SQLEncounter {
                    logger.info("Got encounter from notification: \(encounter.id)")
                    encounterFormMode = .edit(encounter: encounter)
                    logger.info("Set encounterFormMode to edit, sheet should open now")
                } else {
                    logger.error("Failed to extract SQLEncounter from notification")
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
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        nextMonth()
                    case .decrement:
                        previousMonth()
                    @unknown default:
                        break
                    }
                }
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
                    .font(.caption2)
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
                                encounterFormMode = .edit(encounter: encounter)
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
            Menu {
                Button {
                    encounterFormMode = .add(preselectedDate: selectedDate)
                } label: {
                    Label("Create Encounter", systemImage: "square.and.pencil")
                }
                
                Button {
                    showingLiveActivityStart = true
                } label: {
                    Label("Start Live Tracking", systemImage: "timer")
                }
            } label: {
                Label("Add", systemImage: "plus")
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
                logger.error("Failed to delete encounter: \(error)")
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
                    logger.error("Failed to fetch partners for encounter \(encounter.id): \(error.localizedDescription)")
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
