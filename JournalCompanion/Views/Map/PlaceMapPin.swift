//
//  PlaceMapPin.swift
//  JournalCompanion
//
//  Custom annotation view for map pins
//

import SwiftUI

struct PlaceMapPin: View {
    let place: Place
    let isSelected: Bool

    var body: some View {
        ZStack {
            // Colored circle background
            Circle()
                .fill(PlaceIcon.color(for: place.callout))
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.3), radius: isSelected ? 8 : 4)
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 3)
                )

            // Icon from PlaceIconProvider
            Image(systemName: PlaceIcon.systemName(for: place.callout))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Preview
#Preview {
    let samplePlace = Place(
        id: "sample",
        name: "Sample Cafe",
        location: nil,
        address: nil,
        tags: [],
        callout: .cafe,
        pin: nil,
        color: nil,
        url: nil,
        aliases: [],
        content: ""
    )

    HStack(spacing: 20) {
        PlaceMapPin(place: samplePlace, isSelected: false)
        PlaceMapPin(place: samplePlace, isSelected: true)
    }
    .padding()
}
