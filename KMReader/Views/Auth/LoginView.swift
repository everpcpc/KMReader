//
//  LoginView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct LoginView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(AuthViewModel.self) private var authViewModel
  @AppStorage("serverURL") private var serverURL: String = "https://demo.komga.org"
  @AppStorage("username") private var username: String = ""
  @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
  @State private var password = ""
  @State private var instanceName = ""
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

  var body: some View {
    ScrollView {
      VStack(spacing: 32) {
        // Logo/Title Section
        VStack(spacing: 12) {
          Image("Komga")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 72)

          Text("Sign in to Komga")
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(.primary)

          Text("Enter the credentials you use to access your Komga server.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
        }
        .padding(.top, 60)
        .padding(.bottom, 20)

        // Login Form
        VStack(spacing: 20) {
          // Server URL Field
          VStack(alignment: .leading, spacing: 8) {
            Label("Server URL", systemImage: "server.rack")
              .font(.subheadline)
              .foregroundStyle(.secondary)

            HStack {
              Image(systemName: "link")
                .foregroundStyle(.secondary)
                .frame(width: 20)

              TextField("Enter your server URL", text: $serverURL)
                .textContentType(.URL)
                #if canImport(UIKit)
                  .autocapitalization(.none)
                  .keyboardType(.URL)
                #endif
                .autocorrectionDisabled()
            }
            .padding()
            .background(PlatformHelper.secondarySystemBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
          }

          // Instance Name Field (Optional)
          VStack(alignment: .leading, spacing: 8) {
            Label("Instance Name (Optional)", systemImage: "tag")
              .font(.subheadline)
              .foregroundStyle(.secondary)

            HStack {
              Image(systemName: "tag.circle")
                .foregroundStyle(.secondary)
                .frame(width: 20)

              TextField("e.g. \"Home\" or \"Work\"", text: $instanceName)
                .autocorrectionDisabled()
            }
            .padding()
            .background(PlatformHelper.secondarySystemBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
          }

          // Username Field
          VStack(alignment: .leading, spacing: 8) {
            Label("Username", systemImage: "person")
              .font(.subheadline)
              .foregroundStyle(.secondary)

            HStack {
              Image(systemName: "person.circle")
                .foregroundStyle(.secondary)
                .frame(width: 20)

              TextField("Enter your username", text: $username)
                .textContentType(.username)
                #if canImport(UIKit)
                  .autocapitalization(.none)
                #endif
                .autocorrectionDisabled()
            }
            .padding()
            .background(PlatformHelper.secondarySystemBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
          }

          // Password Field
          VStack(alignment: .leading, spacing: 8) {
            Label("Password", systemImage: "lock")
              .font(.subheadline)
              .foregroundStyle(.secondary)

            HStack {
              Image(systemName: "lock.circle")
                .foregroundStyle(.secondary)
                .frame(width: 20)

              SecureField("Enter your password", text: $password)
                .textContentType(.password)
            }
            .padding()
            .background(PlatformHelper.secondarySystemBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
          }

          // Login Button
          Button(action: login) {
            HStack {
              if authViewModel.isLoading {
                ProgressView()
                  .tint(.white)
              } else {
                Image(systemName: "arrow.right.circle.fill")
                  .font(.title3)
                Text("Login")
                  .fontWeight(.semibold)
              }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(.white)
            .background(
              isFormValid
                ? themeColor.color
                : Color.gray.opacity(0.3)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
          }
          .disabled(!isFormValid || authViewModel.isLoading)
          .padding(.top, 8)
        }
        .padding(.horizontal, 24)
      }
      .padding(.bottom, 40)
    }
    .inlineNavigationBarTitle("")
  }

  private var isFormValid: Bool {
    !serverURL.isEmpty && !username.isEmpty && !password.isEmpty
  }

  private func login() {
    Task {
      let trimmedName = instanceName.trimmingCharacters(in: .whitespacesAndNewlines)
      let displayName = trimmedName.isEmpty ? nil : trimmedName
      await authViewModel.login(
        username: username,
        password: password,
        serverURL: serverURL,
        displayName: displayName
      )
      if isLoggedIn {
        dismiss()
      }
    }
  }
}

#Preview {
  NavigationStack {
    LoginView()
      .environment(AuthViewModel())
  }
}
