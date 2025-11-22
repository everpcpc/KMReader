//
//  LoginView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct LoginView: View {
  @Environment(AuthViewModel.self) private var authViewModel
  @AppStorage("serverURL") private var serverURL: String = ""
  @AppStorage("username") private var username: String = ""
  @State private var password = ""
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 32) {
          // Logo/Title Section
          VStack(spacing: 16) {
            Image("Komga")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(height: 80)

            Text("Komga")
              .font(.system(size: 36, weight: .bold))
              .foregroundStyle(.primary)

            Text("Connect to your Komga server")
              .font(.subheadline)
              .foregroundStyle(.secondary)
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

                TextField("https://demo.komga.org", text: $serverURL)
                  .textContentType(.URL)
                  .autocapitalization(.none)
                  .keyboardType(.URL)
                  .autocorrectionDisabled()
              }
              .padding()
              .background(Color(.secondarySystemBackground))
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
                  .autocapitalization(.none)
                  .autocorrectionDisabled()
              }
              .padding()
              .background(Color(.secondarySystemBackground))
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
              .background(Color(.secondarySystemBackground))
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
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private var isFormValid: Bool {
    !serverURL.isEmpty && !username.isEmpty && !password.isEmpty
  }

  private func login() {
    Task {
      await authViewModel.login(username: username, password: password, serverURL: serverURL)
    }
  }
}

#Preview {
  LoginView()
    .environment(AuthViewModel())
}
