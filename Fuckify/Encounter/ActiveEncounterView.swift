//
//  ActiveEncounterView.swift
//  Fuckify
//
//  Full-screen view shown when tapping Live Activity
//

import SwiftUI
import Combine

struct ActiveEncounterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var liveActivityManager = LiveActivityManager.shared
    @State private var currentTime = Date()
    @State private var showingCancelAlert = false
    
    // Timer to update UI
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.1), Color.accentColor.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if let state = liveActivityManager.currentState(),
                   let partners = liveActivityManager.currentPartners {
                    
                    VStack(spacing: 40) {
                        Spacer()
                        
                        // Icon
                        Image(systemName: "bolt.heart.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.accentColor)
                            .symbolEffect(.pulse, options: .repeating)
                        
                        // Timer display
                        VStack(spacing: 8) {
                            Text(formatDuration(state.elapsedActiveTime(currentTime: currentTime)))
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.primary)
                            
                            if state.isPaused {
                                HStack(spacing: 4) {
                                    Image(systemName: "pause.circle.fill")
                                        .font(.caption)
                                    Text("Paused")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.orange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(20)
                            }
                        }
                        
                        // Partners
                        VStack(spacing: 12) {
                            Text("With")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(partners) { partner in
                                    PartnerDisplayChip(partner: partner)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer()
                        
                        // Action buttons
                        VStack(spacing: 16) {
                            // Pause/Resume button
                            Button {
                                Task {
                                    if state.isPaused {
                                        await liveActivityManager.resumeEncounter()
                                    } else {
                                        await liveActivityManager.pauseEncounter()
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                                        .font(.title2)
                                    Text(state.isPaused ? "Resume" : "Pause")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            }
                            
                            // Finish button
                            Button {
                                Task {
                                    // Will be handled by notification observer in FuckifyApp
                                    NotificationCenter.default.post(name: Notification.Name("finishEncounter"), object: nil)
                                    dismiss()
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                    Text("Finish Encounter")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            }
                            
                            // Cancel button
                            Button(role: .destructive) {
                                showingCancelAlert = true
                            } label: {
                                Text("Cancel Encounter")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                } else {
                    // No active encounter
                    ContentUnavailableView(
                        "No Active Encounter",
                        systemImage: "bolt.heart.slash",
                        description: Text("Start a new encounter to track it live")
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Cancel Encounter", isPresented: $showingCancelAlert) {
                Button("Keep Tracking", role: .cancel) { }
                Button("Cancel", role: .destructive) {
                    Task {
                        await liveActivityManager.cancelEncounter()
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to cancel this encounter? All tracking data will be lost.")
            }
            .onReceive(timer) { _ in
                currentTime = Date()
            }
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
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Partner Display Chip

struct PartnerDisplayChip: View {
    let partner: PartnerData
    
    var body: some View {
        HStack(spacing: 8) {
            // Avatar circle
            Circle()
                .fill(partner.color)
                .frame(width: 32, height: 32)
                .overlay {
                    Text(partner.initials)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            
            Text(partner.name)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(partner.color.opacity(0.15))
        .cornerRadius(20)
    }
}

#Preview {
    ActiveEncounterView()
}
