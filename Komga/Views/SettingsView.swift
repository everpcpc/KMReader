//
//  ContentView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsView: View {
  @Environment(AuthViewModel.self) private var authViewModel
  @AppStorage("webtoonPageWidthPercentage") private var webtoonPageWidthPercentage: Double = 100.0
  @AppStorage("themeColorName") private var themeColor: ThemeColorOption = .orange

  var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("Account")) {
          if let user = authViewModel.user {
            HStack {
              Text("Email")
              Spacer()
              Text(user.email)
                .foregroundColor(.secondary)
            }
            HStack {
              Text("Roles")
              Spacer()
              Text(user.roles.joined(separator: ", "))
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.secondary)
            }
          }
        }

        Section(header: Text("Appearance")) {
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Text("Theme Color")
              Spacer()
              Text(themeColor.displayName)
                .foregroundColor(.secondary)
            }

            LazyVGrid(
              columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12
            ) {
              ForEach(ThemeColorOption.allCases, id: \.self) { option in
                Button {
                  themeColor = option
                } label: {
                  Circle()
                    .fill(option.color)
                    .frame(width: 40, height: 40)
                    .overlay(
                      Circle()
                        .stroke(
                          themeColor == option
                            ? Color.primary : Color.primary.opacity(0.2),
                          lineWidth: themeColor == option ? 3 : 1
                        )
                    )
                    .overlay(
                      Group {
                        if themeColor == option {
                          Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1)
                        }
                      }
                    )
                }
                .buttonStyle(.plain)
              }
            }
            .padding(.vertical, 4)
          }
        }

        Section(header: Text("Reader")) {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Webtoon Page Width")
              Spacer()
              Text("\(Int(webtoonPageWidthPercentage))%")
                .foregroundColor(.secondary)
            }
            Slider(
              value: $webtoonPageWidthPercentage,
              in: 50...100,
              step: 5
            )
            Text("Adjust the width of webtoon pages as a percentage of screen width")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Section {
          Button(role: .destructive) {
            authViewModel.logout()
          } label: {
            HStack {
              Spacer()
              Text("Logout")
              Spacer()
            }
          }
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}
