//
//  ChipContainer.swift
//  Fuckify
//
//  Flow layout container for chips
//

import SwiftUI

struct ChipContainer<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        FlowLayout(spacing: 8) {
            content
        }
        .padding(4)
    }
}

#Preview {
    ChipContainer {
        Text("Chip 1")
            .padding(8)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)
        
        Text("Chip 2")
            .padding(8)
            .background(Color.green.opacity(0.2))
            .cornerRadius(8)
    }
}
