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
        headerSection
        formSection
      }
      .padding(.vertical, 40)
      .padding(.horizontal, 24)
      #if os(tvOS)
        .frame(maxWidth: 800)
      #else
        .frame(maxWidth: 520)
      #endif
      .frame(maxWidth: .infinity)
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

  private var headerSection: some View {
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
    .frame(maxWidth: .infinity)
    .padding(.top, 20)
  }

  private var formSection: some View {
    VStack(spacing: 20) {
      FieldContainer(
        title: "Server URL",
        systemImage: "server.rack",
        containerBackground: fieldBackgroundColor
      ) {
        TextField("Enter your server URL", text: $serverURLText)
          .textContentType(.URL)
          #if os(iOS) || os(tvOS)
            .autocapitalization(.none)
            .keyboardType(.URL)
          #endif
          .autocorrectionDisabled()
      }

      FieldContainer(
        title: "Instance Name (Optional)",
        systemImage: "tag",
        containerBackground: fieldBackgroundColor
      ) {
        TextField("e.g. \"Home\" or \"Work\"", text: $instanceName)
          .autocorrectionDisabled()
      }

      FieldContainer(
        title: "Username",
        systemImage: "person",
        containerBackground: fieldBackgroundColor
      ) {
        TextField("Enter your username", text: $usernameText)
          .textContentType(.username)
          #if os(iOS) || os(tvOS)
            .autocapitalization(.none)
          #endif
          .autocorrectionDisabled()
      }

      FieldContainer(
        title: "Password",
        systemImage: "lock",
        containerBackground: fieldBackgroundColor
      ) {
        SecureField("Enter your password", text: $password)
          .textContentType(.password)
      }

      Button(action: login) {
        HStack(spacing: 8) {
          Spacer()
          if authViewModel.isLoading {
            ProgressView()
          } else {
            Text("Login")
            Image(systemName: "arrow.right.circle.fill")
          }
          Spacer()
        }
        .padding(.vertical, 12)
      }
      .adaptiveButtonStyle(.borderedProminent)
      .disabled(!isFormValid || authViewModel.isLoading)
      .padding(.top, 8)
    }
  }

  private var fieldBackgroundColor: Color {
    #if os(macOS)
      Color(nsColor: .textBackgroundColor)
    #elseif os(iOS)
      Color(.secondarySystemBackground)
    #else
      Color.white.opacity(0.08)
    #endif
  }
}

private struct FieldContainer<Content: View>: View {
  let title: String
  let systemImage: String
  let containerBackground: Color
  private let content: Content

  init(
    title: String,
    systemImage: String,
    containerBackground: Color,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.systemImage = systemImage
    self.containerBackground = containerBackground
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: systemImage)
        .font(.subheadline)
        .foregroundStyle(.secondary)

      content
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(containerBackground)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(.primary.opacity(0.05))
        )
    }
  }
}
