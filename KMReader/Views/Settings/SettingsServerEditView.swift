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
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""

  @State private var name: String
  @State private var serverURL: String
  @State private var username: String
  @State private var password: String = ""
  @State private var isValidating = false
  @State private var validationMessage: String?
  @State private var isValidated = false

  private enum ValidationStatus {
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
            .onChange(of: serverURL) {
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
              Text("Leave the password empty to keep the existing credentials.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        ) {
          TextField("Username", text: $username)
            .textContentType(.username)
            #if os(iOS) || os(tvOS)
              .autocapitalization(.none)
            #endif
            .autocorrectionDisabled()
            .onChange(of: username) {
              resetValidation()
            }

          SecureField("Password", text: $password)
            .textContentType(.password)
            .onChange(of: password) {
              resetValidation()
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
              Text("Validate Connection")
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
        Label("Save", systemImage: "checkmark")
      }
      .disabled(!canSave)
    }
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
    trimmedName != instance.name || trimmedServerURL != instance.serverURL
      || trimmedUsername != instance.username || !password.isEmpty
  }

  private var canSave: Bool {
    guard !trimmedServerURL.isEmpty && !trimmedUsername.isEmpty else {
      return false
    }
    // If no changes, disable save
    guard hasChanges else {
      return false
    }
    // If any changes were made (serverURL, username, or password), validation must succeed
    if trimmedServerURL != instance.serverURL || trimmedUsername != instance.username
      || !password.isEmpty
    {
      return isValidated
    }
    // If only name changed, allow save without validation
    return true
  }

  private var canValidate: Bool {
    guard !trimmedServerURL.isEmpty && !trimmedUsername.isEmpty else {
      return false
    }
    // Can validate if password is provided
    if !password.isEmpty {
      return true
    }
    // If password is empty, can only validate if only serverURL changed (username unchanged)
    // If username changed, password must be provided
    return trimmedServerURL != instance.serverURL && trimmedUsername == instance.username
  }

  private func saveChanges() {
    guard canSave else {
      return
    }

    instance.name =
      trimmedName.isEmpty
      ? KomgaInstanceStore.defaultName(serverURL: trimmedServerURL, username: trimmedUsername)
      : trimmedName
    instance.serverURL = trimmedServerURL
    instance.username = trimmedUsername
    if !password.isEmpty {
      guard let token = makeAuthToken(username: trimmedUsername, password: password) else {
        ErrorManager.shared.notify(message: "Unable to encode credentials.")
        return
      }
      instance.authToken = token
    }
    instance.lastUsedAt = Date()

    do {
      try modelContext.save()
      if currentInstanceId == instance.id.uuidString {
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

    // Determine which authToken to use for validation
    let authToken: String
    if !password.isEmpty {
      // If password is provided, always use it to generate new token
      guard let token = makeAuthToken(username: trimmedUsername, password: password) else {
        validationMessage = "Unable to encode credentials"
        isValidated = false
        return
      }
      authToken = token
    } else {
      // If password is empty, check if we can use existing token
      // Only valid if username hasn't changed (username change requires new password)
      if trimmedUsername != instance.username {
        validationMessage = "Username changed, please provide password to validate"
        isValidated = false
        return
      }
      // Use existing authToken when password is empty and only serverURL changed
      authToken = instance.authToken
    }

    isValidating = true
    validationMessage = nil
    isValidated = false

    Task {
      do {
        let _ = try await authViewModel.validate(
          serverURL: trimmedServerURL,
          authToken: authToken
        )
        await MainActor.run {
          validationMessage = "Connection validated successfully"
          isValidated = true
          isValidating = false
        }
      } catch {
        await MainActor.run {
          if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
              validationMessage = "Invalid credentials"
            case .networkError:
              validationMessage = "Network error - check server URL"
            default:
              validationMessage = "Validation failed: \(apiError.localizedDescription)"
            }
          } else {
            validationMessage = "Validation failed: \(error.localizedDescription)"
          }
          isValidated = false
          isValidating = false
        }
      }
    }
  }
}
