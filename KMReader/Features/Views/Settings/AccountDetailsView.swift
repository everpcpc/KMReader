//
//  AccountDetailsView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Flow
import SwiftUI

struct AccountDetailsView: View {
  @Environment(AuthViewModel.self) private var authViewModel
  @State private var showingUpdatePassword = false

  private var user: User? {
    authViewModel.user
  }

  var body: some View {
    Form {
      Section(header: Text(String(localized: "account.details.info"))) {
        HStack {
          Text(String(localized: "User"))
          Spacer()
          Text(user?.email ?? "")
            .foregroundColor(.secondary)
        }

        if let user = user {
          VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Roles"))

            if user.userRoles.isEmpty {
              Text(String(localized: "user.role.none"))
                .foregroundColor(.secondary)
                .italic()
            } else {
              HFlow(spacing: 8) {
                ForEach(user.userRoles, id: \.self) { role in
                  RoleBadge(role: role)
                }
              }
            }
          }
          .padding(.vertical, 4)
        }
      }

      Section {
        Button(role: .destructive) {
          showingUpdatePassword = true
        } label: {
          Text(String(localized: "account.details.changePassword"))
        }
      }
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle(String(localized: "account.details.title"))
    .sheet(isPresented: $showingUpdatePassword) {
      UpdatePasswordSheet()
        .presentationDetents([.medium])
    }
  }
}

// MARK: - Role Badge

struct RoleBadge: View {
  let role: UserRole

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: role.icon)
        .font(.caption)
      Text(role.displayName)
        .font(.footnote)
        .fontWeight(.medium)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(Color.accentColor.opacity(0.15))
    .foregroundColor(.accentColor)
    .clipShape(Capsule())
  }
}

struct UpdatePasswordSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(AuthViewModel.self) private var authViewModel

  @State private var newPassword = ""
  @State private var confirmPassword = ""
  @State private var isUpdating = false
  @State private var showSuccessMessage = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          SecureField(String(localized: "account.details.newPassword"), text: $newPassword)
            .textContentType(.newPassword)
          SecureField(String(localized: "account.details.confirmPassword"), text: $confirmPassword)
            .textContentType(.newPassword)
        } footer: {
          if !newPassword.isEmpty && newPassword != confirmPassword {
            Text(String(localized: "Passwords do not match"))
              .foregroundColor(.red)
          }
        }

        Section {
          Button(action: updatePassword) {
            if isUpdating {
              ProgressView()
                .progressViewStyle(.circular)
            } else {
              Text(String(localized: "account.details.updatePassword"))
                .frame(maxWidth: .infinity)
            }
          }
          .adaptiveButtonStyle(.borderedProminent)
          .disabled(newPassword.isEmpty || newPassword != confirmPassword || isUpdating)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
      }
      .formStyle(.grouped)
      .inlineNavigationBarTitle(String(localized: "account.details.changePassword"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "Cancel")) {
            dismiss()
          }
        }
      }
      .alert(String(localized: "account.details.passwordUpdated"), isPresented: $showSuccessMessage) {
        Button(String(localized: "OK"), role: .cancel) {
          dismiss()
        }
      }
    }
  }

  private func updatePassword() {
    isUpdating = true
    Task {
      do {
        try await authViewModel.updatePassword(password: newPassword)
        showSuccessMessage = true
      } catch {
        ErrorManager.shared.alert(error: error)
      }
      isUpdating = false
    }
  }
}
