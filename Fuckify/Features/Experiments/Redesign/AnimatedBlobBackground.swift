//
//  AnimatedBlobBackground.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2026-05-07.
//

import SwiftUI
import Combine

struct AnimatedBlobBackground: View {
    @State private var time: Double = 0
    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    
    // SPEED CONTROL - Lower = slower, higher = faster
    let movementSpeed: Double = 0.5  // Change this! (0.1 = very slow, 1.0 = fast)
    
    var body: some View {
        ZStack {
            // Animated base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.08 + 0.02 * sin(time * 0.1), green: 0.03, blue: 0.1 + 0.02 * cos(time * 0.12)),
                    Color(red: 0.05, green: 0.02 + 0.01 * sin(time * 0.15), blue: 0.08 + 0.02 * cos(time * 0.08))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Blob layer
            ZStack {
                // Blob 1 - Pink - Starts at "time 0"
                AnimatedGradientBlob(
                    color: Color(red: 1.0, green: 0.41, blue: 0.71),
                    time: time * movementSpeed,
                    xFrequency: 0.3,
                    yFrequency: 0.6,
                    xAmplitude: 0.3,
                    yAmplitude: 0.25,
                    xOffset: 0,
                    yOffset: 0
                )
                
                // Blob 2 - Purple - Starts 1/4 through cycle
                AnimatedGradientBlob(
                    color: Color(red: 0.54, green: 0.17, blue: 0.89),
                    time: time * movementSpeed + 100,  // Time offset
                    xFrequency: 0.4,
                    yFrequency: 0.4,
                    xAmplitude: 0.35,
                    yAmplitude: 0.35,
                    xOffset: .pi / 2,
                    yOffset: 0
                )
                
                // Blob 3 - Deep pink - Starts 1/2 through cycle
                AnimatedGradientBlob(
                    color: Color(red: 1.0, green: 0.08, blue: 0.58),
                    time: time * movementSpeed + 200,  // Time offset
                    xFrequency: 0.5,
                    yFrequency: 0.35,
                    xAmplitude: 0.25,
                    yAmplitude: 0.4,
                    xOffset: .pi,
                    yOffset: .pi / 3
                )
                
                // Blob 4 - Dark purple - Starts 3/4 through cycle
                AnimatedGradientBlob(
                    color: Color(red: 0.3, green: 0.1, blue: 0.4),
                    time: time * movementSpeed + 300,  // Time offset
                    xFrequency: 0.25,
                    yFrequency: 0.45,
                    xAmplitude: 0.3,
                    yAmplitude: 0.3,
                    xOffset: .pi * 1.5,
                    yOffset: .pi / 4
                )
            }
            .padding(-100)
            .blur(radius: 100)
            .clipped()
            .compositingGroup()
        }
        .ignoresSafeArea()
        .onReceive(timer) { _ in
            time += 0.016
        }
    }
}

struct AnimatedGradientBlob: View {
    let color: Color
    let time: Double
    let xFrequency: Double
    let yFrequency: Double
    let xAmplitude: Double
    let yAmplitude: Double
    let xOffset: Double
    let yOffset: Double
    
    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width * (0.5 + xAmplitude * sin(time * xFrequency + xOffset))
            let centerY = geometry.size.height * (0.5 + yAmplitude * cos(time * yFrequency + yOffset))
            
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.9),
                            color.opacity(0.6),
                            color.opacity(0.3),
                            color.opacity(0.1),
                            Color.black.opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 400
                    )
                )
                .frame(width: 900, height: 900)
                .scaleEffect(
                    x: 1.0 + 0.2 * sin(time * 0.3),  // Slight stretching animation
                    y: 1.0 + 0.2 * cos(time * 0.4)
                )
                .position(x: centerX, y: centerY)
                .blendMode(.screen)
        }
    }
}


// Preview
struct AnimatedBlobBackground_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AnimatedBlobBackground()
        }
    }
}
