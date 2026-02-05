//
//  OnboardingView.swift
//  Fuckify
//
//  Onboarding flow for first-time users
//

import SwiftUI

struct OnboardingStep: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
}

private let onboardingSteps = [
    OnboardingStep(
        id: 0,
        icon: "heart.circle.fill",
        title: "Track Your Intimate Life",
        description: "Keep a private record of your encounters, partners, and experiences in a secure, judgment-free space.",
        accentColor: .pink
    ),
    OnboardingStep(
        id: 1,
        icon: "chart.bar.fill",
        title: "Understand Your Patterns",
        description: "Visualize your activity with beautiful charts and insights. See what works for you and your partners.",
        accentColor: .purple
    ),
    OnboardingStep(
        id: 2,
        icon: "lock.shield.fill",
        title: "Your Privacy Matters",
        description: "All data stays on your device. Optional biometric lock keeps your information completely private.",
        accentColor: .blue
    ),
    OnboardingStep(
        id: 3,
        icon: "bell.badge.fill",
        title: "Live Activity Tracking",
        description: "Track encounters in real-time with Live Activities. Pause, resume, and finish right from your Lock Screen.",
        accentColor: .orange
    )
]

private let stepCount = onboardingSteps.count

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @State private var currentStep = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    onboardingSteps[currentStep].accentColor.opacity(0.1),
                    .white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button {
                        hasCompletedOnboarding = true
                    } label: {
                        Text("Skip")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                
                // Content
                TabView(selection: $currentStep) {
                    ForEach(onboardingSteps) { step in
                        VStack(spacing: 32) {
                            Spacer()
                            
                            // Icon
                            Image(systemName: step.icon)
                                .font(.system(size: 100))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [step.accentColor, step.accentColor.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .padding(.bottom, 40)
                            
                            // Title
                            Text(step.title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            // Description
                            Text(step.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                            Spacer()
                        }
                        .tag(step.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<stepCount, id: \.self) { index in
                        if index == currentStep {
                            Capsule()
                                .fill(onboardingSteps[currentStep].accentColor)
                                .frame(width: 24, height: 8)
                        } else {
                            Circle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .padding(.bottom, 24)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                
                // Next/Get Started button
                Button {
                    if currentStep < stepCount - 1 {
                        withAnimation {
                            currentStep += 1
                        }
                    } else {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text(currentStep < stepCount - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [onboardingSteps[currentStep].accentColor, onboardingSteps[currentStep].accentColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: onboardingSteps[currentStep].accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
