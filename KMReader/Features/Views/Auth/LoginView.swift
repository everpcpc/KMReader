//
//  LoginView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
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
  @State private var apiKey = ""
  @State private var instanceName = ""
  @State private var loginErrorMessage: String?
  @State private var authMethod: AuthenticationMethod = .basicAuth

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
    .task {
      serverURLText = serverURL
      usernameText = username
    }
  }

  private var isFormValid: Bool {
    guard !serverURLText.isEmpty else { return false }
    switch authMethod {
    case .basicAuth:
      return !usernameText.isEmpty && !password.isEmpty
    case .apiKey:
      return !apiKey.isEmpty
    }
  }

  private func login() {
    Task {
      loginErrorMessage = nil
      let trimmedName = instanceName.trimmingCharacters(in: .whitespacesAndNewlines)
      let displayName = trimmedName.isEmpty ? nil : trimmedName

      do {
        switch authMethod {
        case .basicAuth:
          try await authViewModel.login(
            username: usernameText,
            password: password,
            serverURL: serverURLText,
            displayName: displayName
          )
        case .apiKey:
          try await authViewModel.loginWithAPIKey(
            apiKey: apiKey,
            serverURL: serverURLText,
            displayName: displayName
          )
        }
        dismiss()
      } catch {
        loginErrorMessage = formattedErrorMessage(from: error)
      }
    }
  }

  private var headerSection: some View {
    VStack(spacing: 12) {
      Image("Komga")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(height: 72)

      Text(String(localized: "Sign in to Komga"))
        .font(.system(size: 32, weight: .bold))
        .foregroundStyle(.primary)

      Text(String(localized: "Enter the credentials you use to access your Komga server."))
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
        TextField(String(localized: "Enter your server URL"), text: $serverURLText)
          .textContentType(.URL)
          #if os(iOS) || os(tvOS)
            .autocapitalization(.none)
            .keyboardType(.URL)
          #endif
          .autocorrectionDisabled()
          .onChange(of: serverURLText) { _, _ in
            loginErrorMessage = nil
          }
      }

      FieldContainer(
        title: "Instance Name (Optional)",
        systemImage: "tag",
        containerBackground: fieldBackgroundColor
      ) {
        TextField(String(localized: "e.g. \"Home\" or \"Work\""), text: $instanceName)
          .autocorrectionDisabled()
      }

      // Auth method picker
      Picker(String(localized: "Authentication Method"), selection: $authMethod) {
        Text(String(localized: "Username & Password")).tag(AuthenticationMethod.basicAuth)
        Text(String(localized: "API Key")).tag(AuthenticationMethod.apiKey)
      }
      .pickerStyle(.segmented)
      .onChange(of: authMethod) { _, _ in
        loginErrorMessage = nil
      }

      // Conditional fields based on auth method
      switch authMethod {
      case .basicAuth:
        FieldContainer(
          title: "Username",
          systemImage: "person",
          containerBackground: fieldBackgroundColor
        ) {
          TextField(String(localized: "Enter your username"), text: $usernameText)
            .textContentType(.username)
            #if os(iOS) || os(tvOS)
              .autocapitalization(.none)
            #endif
            .autocorrectionDisabled()
            .onChange(of: usernameText) { _, _ in
              loginErrorMessage = nil
            }
        }

        FieldContainer(
          title: "Password",
          systemImage: "lock",
          containerBackground: fieldBackgroundColor
        ) {
          SecureField(String(localized: "Enter your password"), text: $password)
            .textContentType(.password)
            .onChange(of: password) { _, _ in
              loginErrorMessage = nil
            }
        }

      case .apiKey:
        FieldContainer(
          title: "API Key",
          systemImage: "key",
          containerBackground: fieldBackgroundColor
        ) {
          SecureField(String(localized: "Enter your API Key"), text: $apiKey)
            .textContentType(.password)
            #if os(iOS) || os(tvOS)
              .autocapitalization(.none)
            #endif
            .autocorrectionDisabled()
            .onChange(of: apiKey) { _, _ in
              loginErrorMessage = nil
            }
        }
      }

      Button(action: login) {
        HStack(spacing: 8) {
          Spacer()
          if authViewModel.isLoading {
            ProgressView()
          } else {
            Text(String(localized: "Login"))
            Image(systemName: "arrow.right.circle.fill")
          }
          Spacer()
        }
        .padding(.vertical, 12)
      }
      .adaptiveButtonStyle(.borderedProminent)
      .disabled(!isFormValid || authViewModel.isLoading)
      .padding(.top, 8)

      if let loginErrorMessage {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
          Text(loginErrorMessage)
            .font(.footnote)
            .foregroundStyle(.red)
            .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
      }
    }
    .animation(.default, value: authMethod)
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

  private func formattedErrorMessage(from error: Error) -> String {
    if let apiError = error as? APIError {
      return apiError.description
    }
    if let localizedError = error as? LocalizedError, let message = localizedError.errorDescription
    {
      return message
    }
    return error.localizedDescription
  }
}

private struct FieldContainer<Content: View>: View {
  let title: LocalizedStringKey
  let systemImage: String
  let containerBackground: Color
  private let content: Content

  init(
    title: LocalizedStringKey,
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
