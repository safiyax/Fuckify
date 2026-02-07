//
//  ContentView.swift
//  Fuckify
//
//  Updated to use SQLite services
//

import SwiftUI
import SQLiteData
import Combine

struct ContentView: View {
    @SceneStorage("selectedTab") var selectedTab = 0
    @State private var partnersManager = PartnersManager()
    @State private var encountersManager = EncountersManager()
    @State private var profile = UserProfile.shared
    @State private var showingActiveEncounter = false
    @State private var liveActivityManager = LiveActivityManager.shared
    
    // Namespace for matched transition
    @Namespace private var animation
    
    // Timer to force UI updates for live timer
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
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
                                .onReceive(timer) { time in
                                    currentTime = time
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
        .onReceive(timer) { time in
            // Update currentTime every second to trigger view refresh for live timer
            currentTime = time
        }
    }
    
    @ViewBuilder
    func NativeTabView() -> some View {
        TabView(selection: $selectedTab) {
            Tab("Activity", systemImage: "bed.double", value: 0) {
                CalendarView()
                    .environment(encountersManager)
            }
            
            Tab("Summary", systemImage: "chart.pie.fill", value: 2) {
                StatisticsView()
                    .environment(encountersManager)
            }

            Tab("Partners", systemImage: "bolt.heart", value: 1) {
                PartnersListView()
                    .environment(partnersManager)
            }

            Tab("Profile", systemImage: "person.crop.circle", value: 3) {
                ProfileView()
            }

            Tab("Search", systemImage: "magnifyingglass", value: 5, role: .search) {
                PartnersListView()
                    .environment(partnersManager)
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
                    if LiveActivityManager.shared.currentState()?.isPaused == true {
                        await LiveActivityManager.shared.resumeEncounter()
                    } else {
                        await LiveActivityManager.shared.pauseEncounter()
                    }
                    // Force a UI update by updating currentTime
                    currentTime = Date()
                }
            } label: {
                Image(systemName: LiveActivityManager.shared.currentState()?.isPaused == true ? "play.fill" : "pause.fill")
                    .contentShape(.rect)
            }
            .padding(.trailing, 10)
            
            // Finish button
            Button {
                Task {
                    if let data = await LiveActivityManager.shared.finishEncounter() {
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
                
                if let state = liveActivityManager.currentState() {
                    // Use currentTime to force live updates every second
                    Text(formatDuration(state.elapsedActiveTime(currentTime: currentTime)))
                        .font(.caption2)
                        .foregroundStyle(.gray)
                        .monospacedDigit()
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }
    
    return ContentView()
}
