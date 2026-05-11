//
//  BottomSheetView.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2026-05-07.
//

import SwiftUI
import BottomSheet

struct BottomSheetView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SheetOverBackgroundView(selectedTab: 0)
                .tabItem {
                    Label("Log", systemImage: "plus")
                }
                .tag(0)
            
            SheetOverBackgroundView(selectedTab: 1)
                .tabItem {
                    Label("Timeline", systemImage: "calendar")
                }
                .tag(1)
            
            SheetOverBackgroundView(selectedTab: 2)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
                .tag(2)
            
//            SheetOverBackgroundView(selectedTab: 3)
//                .tabItem {
//                    Label("Partners", systemImage: "person.2")
//                }
//                .tag(3)
        }
        .tint(Color(red: 1.0, green: 0.41, blue: 0.71))
    }
}

struct SheetOverBackgroundView: View {
    let selectedTab: Int
    @State private var bottomSheetPosition: BottomSheetPosition = .relative(0.55)
    
    var body: some View {
        ZStack {
            // Background with blobs
            AnimatedBlobBackground()
            
            VStack {
                Spacer()
                Text("penis")
                    .italic()
                Spacer()
                Spacer()
                Spacer()
            }
            
            // Invisible base view required for bottomSheet modifier
            Color.clear
                .bottomSheet(
                    bottomSheetPosition: self.$bottomSheetPosition,
                    switchablePositions: [
                        .relative(0.925),  // Almost full screen
                        .relative(0.55)     // Half screen (optional)
                    ],
//                    headerContent: {
//                        // Drag handle
//                        VStack(spacing: 0) {
//                            Capsule()
//                                .fill(Color.white.opacity(0.3))
//                                .frame(width: 36, height: 5)
//                                .padding(.top, 8)
//                                .padding(.bottom, 12)
//                        }
//                    }
                ) {
                    SheetContent(selectedTab: selectedTab)
                }
                .customBackground(
                    Color(uiColor: .systemBackground).cornerRadius(58)
                        .padding(bottomSheetPosition == .relative(0.55) ? 6 : 0)
                )
                .enableSwipeToDismiss(false)
                .enableTapToDismiss(false)
                .dragIndicatorColor(.clear)
                .enableContentDrag()
                .sheetWidth(.relative(1.0))
                .cornerRadius(24)
        }
        .ignoresSafeArea()
    }
}

struct SheetContent: View {
    let selectedTab: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // Sheet header
            HStack {
                Text(tabTitle)
                    .font(.largeTitle.bold())
//                    .italic()
//                    .fontDesign(.serif)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    // Profile action
                } label: {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.pink, Color(red: 1.0, green: 0.08, blue: 0.58)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 42, height: 42)
                        .overlay {
                            Text("SA")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        }
                }
            }
            .padding(.horizontal, 38)
            .padding(.top)
//            .padding(.bottom, 16)
            
//            Divider()
//                .background(Color.primary.opacity(0.1))
            
            // Tab-specific content
//            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case 0:
                        LogView()
                    case 1:
                        ActivityTimelineView()
                    case 2:
                        StatsView()
//                    case 3:
//                        PartnersView()
                    default:
                        EmptyView()
                    }
                }
                .padding()
                .padding(.bottom, 80) // Space for native tab bar
//            }
//            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var tabTitle: String {
        switch selectedTab {
        case 0: return "Log"
        case 1: return "Timeline"
        case 2: return "Stats"
//        case 3: return "Partners"
        default: return ""
        }
    }
}

// Placeholder views
struct LogView: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            // Big + button
            Button {
                // Log new encounter action
            } label: {
                Circle()
                    .fill(Color(red: 1.0, green: 0.41, blue: 0.71))
                    .frame(width: 100, height: 100)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .shadow(color: Color(red: 1.0, green: 0.41, blue: 0.71).opacity(0.4), radius: 20, y: 10)
            }
            
            Text("Log new encounter")
                .font(.headline)
                .foregroundColor(.primary)
            
//            Spacer()
//                .frame(maxHeight: 10)
            
            // Quick access section
            VStack(alignment: .leading, spacing: 12) {
                Text("QUICK ACCESS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Button {
                        // Last partner action
                    } label: {
                        HStack {
                            Image(systemName: "person.fill")
                                .font(.caption)
                            Text("Last partner")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                        .foregroundColor(.primary)
                    }
                    
                    Button {
                        // Repeat last action
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                            Text("Repeat last")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                        .foregroundColor(.primary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct ActivityTimelineView: View {
    var body: some View {
        VStack {
            Text("Timeline Content")
                .foregroundColor(.primary)
        }
    }
}

struct StatsView: View {
    var body: some View {
        VStack {
            Text("Stats Content")
                .foregroundColor(.primary)
        }
    }
}

struct PartnersView: View {
    var body: some View {
        VStack {
            Text("Partners Content")
                .foregroundColor(.primary)
        }
    }
}

// Preview
struct BottomSheetView_Previews: PreviewProvider {
    static var previews: some View {
        BottomSheetView()
    }
}
