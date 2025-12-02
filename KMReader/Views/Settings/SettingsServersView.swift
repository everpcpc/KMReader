//
//  SettingsServersView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SettingsServersView: View {
  enum Mode {
    case management
    case onboarding
  }

  private let mode: Mode

  init(mode: Mode = .management) {
    self.mode = mode
  }

  @Environment(AuthViewModel.self) private var authViewModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: [
    SortDescriptor(\KomgaInstance.lastUsedAt, order: .reverse),
    SortDescriptor(\KomgaInstance.name, order: .forward),
  ]) private var instances: [KomgaInstance]
  @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""

  @State private var instancePendingDeletion: KomgaInstance?
  @State private var editingInstance: KomgaInstance?
  @State private var showLogin = false
  @State private var showLogoutAlert = false

  private var activeInstanceId: String? {
    currentInstanceId.isEmpty ? nil : currentInstanceId
  }

  var body: some View {
    Form {
      if let introText {
        Section {
          Text(introText)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
      }

      Section(footer: footerText) {
        if instances.isEmpty {
          VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
              .font(.largeTitle)
              .foregroundStyle(.secondary)
            Text("No servers found")
              .font(.headline)
            Text("Login to a Komga server to see it listed here.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
            Button("Retry") {
              showLogin = true
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .listRowBackground(Color.clear)
        } else {
          ForEach(instances) { instance in
            serverRow(for: instance)
              .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
              #if os(iOS) || os(macOS)
                .listRowSeparator(.hidden)
              #endif
          }
        }
      }
      .listRowBackground(Color.clear)

      Section {
        Button {
          showLogin = true
        } label: {
          Label(addButtonTitle, systemImage: "plus.circle")
        }
      }

      if mode == .management, isLoggedIn {
        Section {
          Button(role: .destructive) {
            showLogoutAlert = true
          } label: {
            HStack {
              Spacer()
              Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
              Spacer()
            }
          }
        }
      }
    }
    .formStyle(.grouped)
    #if os(iOS) || os(macOS)
      .scrollContentBackground(.hidden)
    #endif
    .inlineNavigationBarTitle(navigationTitle)
    .sheet(item: $editingInstance) { instance in
      SettingsServerEditView(instance: instance)
    }
    .alert(
      "Delete Server",
      isPresented: Binding(
        get: { instancePendingDeletion != nil },
        set: { isPresented in
          if !isPresented {
            instancePendingDeletion = nil
          }
        }
      ),
      presenting: instancePendingDeletion
    ) { instance in
      Button("Delete", role: .destructive) {
        delete(instance)
      }
      Button("Cancel", role: .cancel) {}
    } message: { instance in
      Text(
        "This will remove \(instance.name), its credentials, and all cached data for this server."
      )
    }
    .alert("Logout", isPresented: $showLogoutAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Logout", role: .destructive) {
        authViewModel.logout()
      }
    } message: {
      Text("Are you sure you want to logout?")
    }
    #if os(macOS)
      .sheet(isPresented: $showLogin) {
        NavigationStack {
          LoginView()
        }
        .frame(minWidth: 400, minHeight: 600)
      }
    #else
      .navigationDestination(isPresented: $showLogin) {
        LoginView()
      }
    #endif
    .onChange(of: isLoggedIn) { _, loggedIn in
      if loggedIn && mode == .onboarding {
        dismiss()
      }
    }
  }

  private var navigationTitle: String {
    switch mode {
    case .management:
      return "Servers"
    case .onboarding:
      return "Get Started"
    }
  }

  private var introText: String? {
    switch mode {
    case .management:
      return nil
    case .onboarding:
      return "Choose an existing Komga server or add a new one to begin."
    }
  }

  private var footerText: some View {
    Text("Credentials are stored locally so you can switch servers without re-entering them.")
  }

  private var addServerSection: some View {
    Section {
      Button {
        showLogin = true
      } label: {
        Label(addButtonTitle, systemImage: "plus.circle")
      }
    }
  }

  private var addButtonTitle: String {
    switch mode {
    case .management:
      return "Add Another Server"
    case .onboarding:
      return "Connect to a Server"
    }
  }

  private func serverRow(for instance: KomgaInstance) -> some View {
    Button {
      withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
        switchTo(instance)
      }
    } label: {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
          Text(instance.displayName)
            .font(.headline)
            .foregroundStyle(.primary)
          Spacer()
          if isActive(instance) {
            Label("Active", systemImage: "checkmark.seal.fill")
              .font(.caption)
              .foregroundStyle(themeColor.color)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(
                Capsule()
                  .fill(themeColor.color.opacity(0.2))
              )
          }
        }

        detailRow(icon: "globe", text: instance.serverURL)
        detailRow(icon: "person", text: "User: \(instance.username)")
        detailRow(
          icon: "shield",
          text: instance.isAdmin ? "Role: Admin" : "Role: User",
          color: instance.isAdmin ? .green : .secondary)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(
            isActive(instance)
              ? themeColor.color.opacity(0.15)
              : Color.secondary.opacity(0.1)
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(
            isActive(instance)
              ? themeColor.color.opacity(0.5)
              : Color.primary.opacity(0.08),
            lineWidth: 1.5
          )
      )
      .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    .animation(.easeInOut(duration: 0.25), value: isActive(instance))
    .adaptiveButtonStyle(.plain)
    .disabled(isActive(instance))
    #if os(iOS) || os(macOS)
      .swipeActions(edge: .trailing) {
        if !isActive(instance) {
          Button {
            editingInstance = instance
          } label: {
            Label("Edit", systemImage: "pencil")
          }

          Button(role: .destructive) {
            instancePendingDeletion = instance
          } label: {
            Label("Delete", systemImage: "trash")
          }
        }
      }
    #endif
    .contextMenu {
      if !isActive(instance) {
        Button {
          editingInstance = instance
        } label: {
          Label("Edit", systemImage: "pencil")
        }

        Button(role: .destructive) {
          instancePendingDeletion = instance
        } label: {
          Label("Delete", systemImage: "trash")
        }
      }
    }
  }

  private func isActive(_ instance: KomgaInstance) -> Bool {
    activeInstanceId == instance.id.uuidString
  }

  private func switchTo(_ instance: KomgaInstance) {
    guard !isActive(instance) else { return }
    authViewModel.switchTo(instance: instance)
    instance.lastUsedAt = Date()
    saveChanges()
  }

  private func delete(_ instance: KomgaInstance) {
    if isActive(instance) {
      authViewModel.logout()
    }
    modelContext.delete(instance)
    saveChanges()
    instancePendingDeletion = nil
    Task {
      await CacheManager.clearCaches(instanceId: instance.id.uuidString)
    }
    LibraryManager.shared.removeLibraries(for: instance.id.uuidString)
  }

  private func saveChanges() {
    do {
      try modelContext.save()
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  @ViewBuilder
  private func detailRow(icon: String, text: String, color: Color = .secondary) -> some View {
    HStack(alignment: .center, spacing: 8) {
      Image(systemName: icon)
        .font(.subheadline)
        .foregroundStyle(color)
        .frame(width: 16)
      Text(text)
        .font(.footnote)
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.9)
      Spacer()
    }
  }
}
