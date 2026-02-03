//
//  LandingView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct LandingView: View {
  @State private var showGetStarted = false
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

  var body: some View {
    VStack(spacing: 40) {
      Spacer()

      // Logo
      Image("logo")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(height: 120)

      // App Name
      Text("KMReader")
        .font(.system(size: 42, weight: .bold))
        .foregroundStyle(.primary)

      // Tagline
      Text("Your personal manga and comic reader")
        .font(.title3)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)

      Spacer()

      // Get Started Button
      Button(action: {
        showGetStarted = true
      }) {
        HStack {
          Text("Get Started")
            .fontWeight(.semibold)
          Image(systemName: "arrow.right")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
      }
      .adaptiveButtonStyle(.borderedProminent)
      .padding(.horizontal, 40)
      .padding(.bottom, 60)
    }
    #if os(iOS)
      .fullScreenCover(isPresented: $showGetStarted) {
        SheetView(title: "Get Started") {
          ServerListView(mode: .onboarding)
        }
        .tint(themeColor.color)
        .accentColor(themeColor.color)
      }
    #else
      .sheet(isPresented: $showGetStarted) {
        SheetView(title: "Get Started", applyFormStyle: true) {
          ServerListView(mode: .onboarding)
        }
      }
    #endif
  }
}

#Preview {
  LandingView()
    .environment(AuthViewModel())
}
