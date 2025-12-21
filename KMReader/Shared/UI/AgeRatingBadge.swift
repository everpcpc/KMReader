//
//  AgeRatingBadge.swift
//  KMReader
//
//  Created by Anitgravity
//

import SwiftUI

struct AgeRatingBadge: View {
  let ageRating: Int

  private var backgroundColor: Color {
    if ageRating >= 18 {
      return .black
    } else if ageRating >= 16 {
      return .red
    } else if ageRating >= 12 {
      return .orange
    } else {
      return .green
    }
  }

  var body: some View {
    Text("\(ageRating)+")
      .font(.caption2.weight(.heavy))
      .foregroundColor(.white)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
          .fill(backgroundColor)
          .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
              .strokeBorder(.white.opacity(0.3), lineWidth: 1)
          }
      }
      .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
  }
}

#Preview {
  VStack {
    AgeRatingBadge(ageRating: 0)
    AgeRatingBadge(ageRating: 12)
    AgeRatingBadge(ageRating: 16)
    AgeRatingBadge(ageRating: 18)
  }
  .padding()
  .background(Color.gray)
}
