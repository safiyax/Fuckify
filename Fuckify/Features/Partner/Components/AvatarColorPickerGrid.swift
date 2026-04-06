//
//  AvatarColorPickerGrid.swift
//  Fuckify
//
//  Color picker grid for partner avatars
//

import SwiftUI

struct AvatarColorPickerGrid: View {
    @Binding var selectedColor: String
    
    var body: some View {
        Section("Avatar Color") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                ForEach(PartnerColors.allColorNames, id: \.self) { colorName in
                    Button(action: { selectedColor = colorName }) {
                        ZStack {
                            Circle()
                                .fill(Color.fromPartnerColorName(colorName))
                                .frame(width: 50, height: 50)

                            if selectedColor == colorName {
                                Image(systemName: "checkmark")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(colorName.capitalized) color")
                    .accessibilityAddTraits(selectedColor == colorName ? .isSelected : [])
                    .accessibilityHint("Double tap to select \(colorName) as avatar color")
                }
            }
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    Form {
        AvatarColorPickerGrid(selectedColor: .constant("blue"))
    }
}
