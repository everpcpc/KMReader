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

  init(instance: KomgaInstance) {
    _instance = Bindable(instance)
    _name = State(initialValue: instance.name)
    _serverURL = State(initialValue: instance.serverURL)
    _username = State(initialValue: instance.username)
  }

  var body: some View {
    NavigationStack {
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
        }

        Section(
          header: Text("Credentials"),
          footer: Text("Leave the password empty to keep the existing credentials.")
        ) {
          TextField("Username", text: $username)
            .textContentType(.username)
            #if os(iOS) || os(tvOS)
              .autocapitalization(.none)
            #endif
            .autocorrectionDisabled()

          SecureField("Password", text: $password)
            .textContentType(.password)
        }

        Section {
          HStack(spacing: 12) {
            Button("Cancel") {
              dismiss()
            }
            .buttonStyle(.bordered)

            Button("Save") {
              saveChanges()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .formStyle(.grouped)
      #if os(tvOS)
        .focusSection()
      #endif
      .inlineNavigationBarTitle("Edit Server")
      .padding(PlatformHelper.sheetPadding)
    }
    .platformSheetPresentation(detents: [.large], minWidth: 600, minHeight: 400)
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

  private var canSave: Bool {
    !trimmedServerURL.isEmpty && !trimmedUsername.isEmpty
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
        authViewModel.switchTo(instance: instance)
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
}
