//
//  GlassEffect.swift
//  Fuckify
//
//  Custom glass effect modifier and button style with iOS 18+ compatibility
//  Uses LiquidGlassKit for backported liquid glass effects on iOS 13-25
//

import SwiftUI
import LiquidGlassKit
import UIKit

// MARK: - Glass Effect Modifier

extension View {
    /// Applies a glass-like effect to the view.
    /// Uses native `.glassEffect()` on iOS 26+, falls back to LiquidGlassKit on iOS 18-25
    @ViewBuilder
    func compatibleGlassEffect() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect()
        } else {
            self.overlay(
                LiquidGlassEffectWrapper()
                    .mask(self)
            )
        }
    }
}

/// SwiftUI wrapper for LiquidGlassKit's effect view
/// Uses the factory function VisualEffectView() which automatically handles iOS version compatibility
struct LiquidGlassEffectWrapper: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        // Create effect with isNative: true so it uses native on iOS 26+ if available
        let effect = LiquidGlassEffect(style: .regular, isNative: true)
        // VisualEffectView is the factory function from LiquidGlassKit
        // It returns AnyVisualEffectView which is either UIVisualEffectView (iOS 26+) or LiquidGlassEffectView (iOS 13-25)
        let effectView = VisualEffectView(effect: effect)
        return effectView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
}

// MARK: - Glass Prominent Button Style

extension ButtonStyle where Self == CompatibleGlassProminentButtonStyle {
    /// A glass prominent button style compatible with iOS 18+
    /// Uses native `.glassProminent` on iOS 26+, falls back to LiquidGlassKit on iOS 18-25
    static var compatibleGlassProminent: CompatibleGlassProminentButtonStyle {
        CompatibleGlassProminentButtonStyle()
    }
}

extension ButtonStyle where Self == CompatibleGlassButtonStyle {
    static var compatibleGlass: CompatibleGlassButtonStyle {
        CompatibleGlassButtonStyle()
    }
}

struct CompatibleGlassProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            configuration.label
                .buttonStyle(.glassProminent)
        } else {
            configuration.label
                .foregroundStyle(.white)
                .fontWeight(.semibold)
                .padding(12)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.5))
                        .overlay(
                            Circle()
                                .fill(.clear)
                                .compatibleGlassEffect()
                        )
                )
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}

struct CompatibleGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            configuration.label
        } else {
            configuration.label
                .foregroundStyle(.white)
                .fontWeight(.semibold)
                .padding(12)
                .background(
                    Circle()
                        .fill(.gray)
                        .overlay(
                            Circle()
                                .fill(.clear)
                                .compatibleGlassEffect()
                        )
                )
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}
