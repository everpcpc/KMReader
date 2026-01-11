//
//  SettingsServerEditView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SettingsServerEditView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(AuthViewModel.self) private var authViewModel
  @Bindable var instance: KomgaInstance
  @AppStorage("currentAccount") private var current: Current = .init()

  @State private var name: String
  @State private var serverURL: String
  @State private var username: String
  @State private var password: String = ""
  @State private var apiKey: String = ""
  @State private var authMethod: AuthenticationMethod
  @State private var isValidating = false
  @State private var validationMessage: String?
  @State private var isValidated = false

  private enum ValidationStatus: Equatable {
    case success(String)
    case error(String)
    case none
  }

  private var validationStatus: ValidationStatus {
    guard let message = validationMessage else {
      return .none
    }
    if isValidated {
      return .success(message)
    } else {
      return .error(message)
    }
  }

  init(instance: KomgaInstance) {
    _instance = Bindable(instance)
    _name = State(initialValue: instance.name)
    _serverURL = State(initialValue: instance.serverURL)
    _username = State(initialValue: instance.username)
    _authMethod = State(initialValue: instance.resolvedAuthMethod)
    if instance.resolvedAuthMethod == .apiKey {
      _apiKey = State(initialValue: instance.authToken)
    }
  }

  var body: some View {
    SheetView(title: String(localized: "Edit Server"), size: .large, applyFormStyle: true) {
      Form {
        Section(header: Text("Display")) {
          TextField("Name", text: $name)
        }

        Section(header: Text("Server")) {
          TextField("Server URL", text: $serverURL)
            .textContentType(.URL)
            #if os(iOS) || os(tvOS)
              .autocapitalization(.none)
              .keyboardType(.URL)
            #endif
            .autocorrectionDisabled()
            .onChange(of: serverURL) { _, _ in
              resetValidation()
            }
        }

        Section(
          header: Text("Credentials"),
          footer: Group {
            switch validationStatus {
            case .success(let message):
              HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundStyle(.green)
                  .font(.caption)
                Text(message)
                  .foregroundStyle(.green)
                  .font(.caption)
              }
            case .error(let message):
              HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundStyle(.red)
                  .font(.caption)
                Text(message)
                  .foregroundStyle(.red)
                  .font(.caption)
              }
            case .none:
              if authMethod == .basicAuth {
                Text(
                  String(localized: "Leave the password empty to keep the existing credentials.")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
              }
            }
          }
        ) {
          Picker(String(localized: "Authentication Method"), selection: $authMethod) {
            Text(String(localized: "Username & Password")).tag(AuthenticationMethod.basicAuth)
            Text(String(localized: "API Key")).tag(AuthenticationMethod.apiKey)
          }
          .pickerStyle(.segmented)
          .onChange(of: authMethod) { _, _ in
            resetValidation()
          }

          if authMethod == .basicAuth {
            TextField(String(localized: "Username"), text: $username)
              .textContentType(.username)
              #if os(iOS) || os(tvOS)
                .autocapitalization(.none)
              #endif
              .autocorrectionDisabled()
              .onChange(of: username) { _, _ in
                resetValidation()
              }

            SecureField(String(localized: "Password"), text: $password)
              .textContentType(.password)
              .onChange(of: password) { _, _ in
                resetValidation()
              }
          } else {
            SecureField(String(localized: "API Key"), text: $apiKey)
              .textContentType(.password)
              #if os(iOS) || os(tvOS)
                .autocapitalization(.none)
              #endif
              .autocorrectionDisabled()
              .onChange(of: apiKey) { _, _ in
                resetValidation()
              }
          }

          Button {
            validateConnection()
          } label: {
            HStack {
              if isValidating {
                ProgressView()
                  .scaleEffect(0.8)
              } else {
                Image(systemName: "checkmark.circle")
              }
              Text(String(localized: "Validate Connection"))
            }
            .frame(maxWidth: .infinity)
          }
          .adaptiveButtonStyle(.bordered)
          .disabled(isValidating || !canValidate)
        }
      }
      #if os(tvOS)
        .focusSection()
      #endif
    } controls: {
      Button {
        saveChanges()
      } label: {
        Label(String(localized: "Save"), systemImage: "checkmark")
      }
      .disabled(!canSave)
    }
    .animation(.default, value: authMethod)
    .animation(.default, value: validationStatus)
  }

  private var trimmedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var trimmedServerURL: String {
    serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var trimmedUsername: String {
    username.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var hasChanges: Bool {
    if trimmedName != instance.name || trimmedServerURL != instance.serverURL
      || authMethod != instance.resolvedAuthMethod
    {
      return true
    }
    if authMethod == .basicAuth {
      return trimmedUsername != instance.username || !password.isEmpty
    } else {
      return apiKey != instance.authToken
    }
  }

  private var canSave: Bool {
    guard !trimmedServerURL.isEmpty else { return false }

    if authMethod == .basicAuth {
      guard !trimmedUsername.isEmpty else { return false }
    } else {
      guard !apiKey.isEmpty else { return false }
    }

    // If no changes, disable save
    guard hasChanges else {
      return false
    }

    // If only name changed, allow save without validation
    let isCredsChanged: Bool
    if authMethod == .basicAuth {
      isCredsChanged =
        trimmedServerURL != instance.serverURL || trimmedUsername != instance.username
        || !password.isEmpty || authMethod != instance.resolvedAuthMethod
    } else {
      isCredsChanged =
        trimmedServerURL != instance.serverURL || apiKey != instance.authToken
        || authMethod != instance.resolvedAuthMethod
    }

    if isCredsChanged {
      return isValidated
    }

    return true
  }

  private var canValidate: Bool {
    guard !trimmedServerURL.isEmpty else { return false }

    if authMethod == .basicAuth {
      guard !trimmedUsername.isEmpty else { return false }
      // Can validate if password is provided
      if !password.isEmpty { return true }
      // If password is empty, can only validate if only serverURL changed (username unchanged)
      // If username changed, password must be provided
      return trimmedServerURL != instance.serverURL && trimmedUsername == instance.username
        && instance.resolvedAuthMethod == .basicAuth
    } else {
      return !apiKey.isEmpty
    }
  }

  private func saveChanges() {
    guard canSave else {
      return
    }

    instance.name =
      trimmedName.isEmpty
      ? defaultInstanceName(serverURL: trimmedServerURL)
      : trimmedName
    instance.serverURL = trimmedServerURL
    instance.authMethod = authMethod

    if authMethod == .basicAuth {
      instance.username = trimmedUsername
      if !password.isEmpty {
        guard let token = makeAuthToken(username: trimmedUsername, password: password) else {
          ErrorManager.shared.notify(
            message: String(localized: "notification.settings.encodeCredentialsFailed"))
          return
        }
        instance.authToken = token
      }
    } else {
      // For API Key, we use the key as the token directly
      instance.authToken = apiKey
      // API Key auth returns a User object, so we can use that email/username
    }

    instance.lastUsedAt = Date()

    do {
      try modelContext.save()
      if current.instanceId == instance.id.uuidString {
        Task {
          _ = await authViewModel.switchTo(instance: instance)
        }
      }
      dismiss()
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  private func makeAuthToken(username: String, password: String) -> String? {
    let credentials = "\(username):\(password)"
    return credentials.data(using: .utf8)?.base64EncodedString()
  }

  private func resetValidation() {
    isValidated = false
    validationMessage = nil
  }

  private func validateConnection() {
    guard canValidate else {
      return
    }

    // Determine which authToken/credentials to use for validation
    let tokenToTest: String
    if authMethod == .basicAuth {
      if !password.isEmpty {
        guard let token = makeAuthToken(username: trimmedUsername, password: password) else {
          validationMessage = String(localized: "Unable to encode credentials")
          isValidated = false
          return
        }
        tokenToTest = token
      } else {
        // Reuse existing token
        tokenToTest = instance.authToken
      }
    } else {
      tokenToTest = apiKey
    }

    isValidating = true
    validationMessage = nil
    isValidated = false

    Task {
      do {
        // We validate and get the user.
        // If API Key, this will return the user associated with the key.
        let user = try await authViewModel.testCredentials(
          serverURL: trimmedServerURL,
          authToken: tokenToTest,
          authMethod: authMethod
        )

        await MainActor.run {
          validationMessage = String(localized: "Connection validated successfully")
          isValidated = true
          isValidating = false

          // Update username if using API Key so it's correct when saving
          if authMethod == .apiKey {
            self.username = user.email
          }
        }
      } catch {
        await MainActor.run {
          if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
              validationMessage = String(localized: "Invalid credentials")
            case .networkError:
              validationMessage = String(localized: "Network error - check server URL")
            default:
              validationMessage = String(
                localized: "Validation failed: \(apiError.localizedDescription)")
            }
          } else {
            validationMessage = String(
              localized: "Validation failed: \(error.localizedDescription)")
          }
          isValidated = false
          isValidating = false
        }
      }
    }
  }

  private func defaultInstanceName(serverURL: String) -> String {
    if let host = URL(string: serverURL)?.host, !host.isEmpty {
      return host
    }
    return serverURL
  }
}
