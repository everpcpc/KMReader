//
//  LoginView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct LoginView: View {
  @Environment(AuthViewModel.self) private var authViewModel
  @State private var serverURL = ""
  @State private var username = ""
  @State private var password = ""

  var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("Server")) {
          TextField("Server URL", text: $serverURL)
            .textContentType(.URL)
            .autocapitalization(.none)
            .keyboardType(.URL)
        }

        Section(header: Text("Credentials")) {
          TextField("Username", text: $username)
            .textContentType(.emailAddress)
            .autocapitalization(.none)

          SecureField("Password", text: $password)
            .textContentType(.password)
        }

        Section {
          Button(action: login) {
            if authViewModel.isLoading {
              HStack {
                Spacer()
                ProgressView()
                Spacer()
              }
            } else {
              HStack {
                Spacer()
                Text("Login")
                  .fontWeight(.semibold)
                Spacer()
              }
            }
          }
          .disabled(
            serverURL.isEmpty || username.isEmpty || password.isEmpty || authViewModel.isLoading)
        }

        if let errorMessage = authViewModel.errorMessage {
          Section {
            Text(errorMessage)
              .foregroundColor(.red)
              .font(.caption)
          }
        }
      }
      .navigationTitle("Komga")
    }
  }

  private func login() {
    Task {
      await authViewModel.login(username: username, password: password, serverURL: serverURL)
    }
  }
}

#Preview {
  LoginView()
}
