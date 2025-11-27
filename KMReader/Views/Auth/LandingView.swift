//
//  LandingView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct LandingView: View {
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange
  @State private var showLogin = false

  var body: some View {
    NavigationStack {
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
          showLogin = true
        }) {
          HStack {
            Text("Get Started")
              .fontWeight(.semibold)
            Image(systemName: "arrow.right")
          }
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .foregroundStyle(.white)
          .background(themeColor.color)
          .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 60)
      }
      .navigationDestination(isPresented: $showLogin) {
        LoginView()
      }
    }
  }
}

#Preview {
  LandingView()
    .environment(AuthViewModel())
}
