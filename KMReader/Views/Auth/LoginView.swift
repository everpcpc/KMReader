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
  @State private var serverURLText: String = ""
  @State private var usernameText: String = ""
  @State private var password = ""
  @State private var instanceName = ""

  var body: some View {
    ScrollView {
      VStack(spacing: 32) {
        // Logo/Title Section
        VStack(spacing: 12) {
          Image("Komga")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 72)
            .drawingGroup()

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

              TextField("Enter your server URL", text: $serverURLText)
                .textContentType(.URL)
                #if os(iOS) || os(tvOS)
                  .autocapitalization(.none)
                  .keyboardType(.URL)
                #endif
                .autocorrectionDisabled()
            }
            .padding()
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

              TextField("Enter your username", text: $usernameText)
                .textContentType(.username)
                #if os(iOS) || os(tvOS)
                  .autocapitalization(.none)
                #endif
                .autocorrectionDisabled()
            }
            .padding()
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
            .clipShape(RoundedRectangle(cornerRadius: 12))
          }

          // Login Button
          Button(action: login) {
            HStack {
              if authViewModel.isLoading {
                ProgressView()
              } else {
                Text("Login")
                  .fontWeight(.semibold)
                Image(systemName: "arrow.right.circle.fill")
                  .font(.title3)
              }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
          }
          .buttonStyle(.borderedProminent)
          .disabled(!isFormValid || authViewModel.isLoading)
          .padding(.top, 8)
        }
        .padding(.horizontal, 24)
      }
      .padding(.bottom, 40)
    }
    .inlineNavigationBarTitle("Connect to a Server")
    .task {
      serverURLText = serverURL
      usernameText = username
    }
  }

  private var isFormValid: Bool {
    !serverURLText.isEmpty && !usernameText.isEmpty && !password.isEmpty
  }

  private func login() {
    Task {
      let trimmedName = instanceName.trimmingCharacters(in: .whitespacesAndNewlines)
      let displayName = trimmedName.isEmpty ? nil : trimmedName
      // Save to AppStorage
      serverURL = serverURLText
      username = usernameText
      await authViewModel.login(
        username: usernameText,
        password: password,
        serverURL: serverURLText,
        displayName: displayName
      )
      if isLoggedIn {
        dismiss()
      }
    }
  }
}
