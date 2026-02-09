//
//  ContentView.swift
//  Fuckify
//
//  Updated to use SQLite services
//

import SwiftUI
import SQLiteData

struct ContentView: View {
    @SceneStorage("selectedTab") var selectedTab = 0
    @State private var partnersViewModel = PartnersViewModel()
    @State private var encountersViewModel = EncountersViewModel()
    @Environment(UserProfile.self) private var profile
    @State private var showingActiveEncounter = false
    @Environment(LiveActivityManager.self) private var liveActivityManager
    
    // Namespace for matched transition
    @Namespace private var animation
    
    var body: some View {
        Group {
            if #available(iOS 26.1, *) {
                NativeTabView()
                    .tabBarMinimizeBehavior(liveActivityManager.isActive ? .onScrollDown : .never)
                    .tabViewBottomAccessory(isEnabled: liveActivityManager.isActive) {
                        if liveActivityManager.isActive {
                            MiniPlayerView()
                                .matchedTransitionSource(id: "MINIPLAYER", in: animation)
                                .onTapGesture {
                                    showingActiveEncounter.toggle()
                                }
                        }
                    }
            } else if #available(iOS 26, *) {
                NativeTabView()
                    .if(liveActivityManager.isActive) { view in
                        view
                            .tabBarMinimizeBehavior(liveActivityManager.isActive ? .onScrollDown : .never)
                            .tabViewBottomAccessory {
                                MiniPlayerView()
                                    .matchedTransitionSource(id: "MINIPLAYER", in: animation)
                                    .onTapGesture {
                                        showingActiveEncounter.toggle()
                                    }
                            }
                    }
            } else {
                NativeTabView()
                    .overlay(alignment: .bottom) {
                        if liveActivityManager.isActive {
                            MiniPlayerView()
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: .rect(cornerRadius: 15, style: .continuous))
                                .matchedTransitionSource(id: "MINIPLAYER", in: animation)
                                .onTapGesture {
                                    showingActiveEncounter.toggle()
                                }
                                
                                .offset(y: -60)
                                .padding(.horizontal, 15)
                        }
                    }
                    .ignoresSafeArea(.keyboard, edges: .all)
            }
        }
        .fullScreenCover(isPresented: $showingActiveEncounter) {
            ActiveEncounterView()
                .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("showActiveEncounter"))) { _ in
            showingActiveEncounter = true
        }
    }
    
    @ViewBuilder
    func NativeTabView() -> some View {
        TabView(selection: $selectedTab) {
            Tab("Activity", systemImage: "bed.double", value: 0) {
                CalendarView()
                    .environment(encountersViewModel)
            }
            
            Tab("Summary", systemImage: "chart.pie.fill", value: 2) {
                StatisticsView()
                    .environment(encountersViewModel)
            }

            Tab("Partners", systemImage: "bolt.heart", value: 1) {
                PartnersListView()
                    .environment(partnersViewModel)
            }

            Tab("Profile", systemImage: "person.crop.circle", value: 3) {
                ProfileView()
            }

            Tab("Search", systemImage: "magnifyingglass", value: 5, role: .search) {
                PartnersListView()
                    .environment(partnersViewModel)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
    
    @ViewBuilder
    func MiniPlayerView() -> some View {
        HStack(spacing: 15) {
            PlayerInfo(.init(width: 30, height: 30))
            
            Spacer(minLength: 0)
            
            // Pause/Resume button
            Button {
                Task {
                    if liveActivityManager.currentState()?.isPaused == true {
                        await liveActivityManager.resumeEncounter()
                    } else {
                        await liveActivityManager.pauseEncounter()
                    }
                }
            } label: {
                Image(systemName: liveActivityManager.currentState()?.isPaused == true ? "play.fill" : "pause.fill")
                    .contentShape(.rect)
            }
            .padding(.trailing, 10)
            
            // Finish button
            Button {
                Task {
                    if let data = await liveActivityManager.finishEncounter() {
                        NotificationCenter.default.post(
                            name: Notification.Name("finishEncounter"),
                            object: nil,
                            userInfo: [
                                "duration": data.duration,
                                "partnerIDs": data.partnerIDs,
                                "encounterID": data.encounterID,
                                "startTime": data.startTime
                            ]
                        )
                    }
                }
            } label: {
                Image(systemName: "checkmark")
                    .contentShape(.rect)
            }
        }
        .padding(.vertical, 15)
        .contentShape(.rect)
        .foregroundStyle(.primary)
        .padding(.horizontal, 15)
    }
    
    @ViewBuilder
    func PlayerInfo(_ size: CGSize) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.heart.fill")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size.width, height: size.height)
            
            VStack(alignment: .leading, spacing: 0) {
                if let partners = liveActivityManager.currentPartners {
                    Text(formatPartnerNames(partners))
                        .font(.callout)
                } else {
                    Text("Encounter in Progress")
                        .font(.callout)
                }
                
                if liveActivityManager.currentState() != nil {
                    // TimelineView updates only this text every second
                    // This avoids re-rendering the entire ContentView body
                    TimelineView(.periodic(from: Date(), by: 1.0)) { context in
                        if let state = liveActivityManager.currentState() {
                            Text(formatDuration(state.elapsedActiveTime(currentTime: context.date)))
                                .font(.caption2)
                                .foregroundStyle(.gray)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .lineLimit(1)
        }
    }
    
    private func formatPartnerNames(_ partners: [PartnerData]) -> String {
        let names = partners.map(\.name)
        if names.count <= 2 {
            return names.joined(separator: " & ")
        } else if names.count == 3 {
            return "\(names[0]), \(names[1]) & \(names[2])"
        } else {
            return "\(names[0]), \(names[1]) & \(names.count - 2) more"
        }
    }
    
    /// Format duration as H:MM:SS or M:SS using modern Swift formatting
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            // Format: H:MM:SS (e.g., "1:23:45")
            return "\(hours):\(minutes.formatted(.number.precision(.integerLength(2)))):\(seconds.formatted(.number.precision(.integerLength(2))))"
        } else {
            // Format: M:SS (e.g., "3:45")
            return "\(minutes):\(seconds.formatted(.number.precision(.integerLength(2))))"
        }
    }
}

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }
    
    return ContentView()
}
