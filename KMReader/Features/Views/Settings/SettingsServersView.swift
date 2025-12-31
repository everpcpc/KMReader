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
      Section(header: introHeader, footer: footerText) {
        if instances.isEmpty {
          VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
              .font(.largeTitle)
              .foregroundStyle(.secondary)
            Text(String(localized: "No servers found"))
              .font(.headline)
            Text(String(localized: "Login to a Komga server to see it listed here."))
              .font(.caption)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
            Button(String(localized: "Retry")) {
              showLogin = true
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical)
          .listRowBackground(Color.clear)
        } else {
          ForEach(instances) { instance in
            ServerRowView(
              instance: instance,
              isSwitching: isSwitching(instance),
              isActive: isActive(instance),
              onSelect: {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                  switchTo(instance)
                }
              },
              onEdit: {
                editingInstance = instance
              },
              onDelete: {
                instancePendingDeletion = instance
              }
            )
          }
        }
      }
      .listRowBackground(Color.clear)

      Section {
        Button {
          showLogin = true
        } label: {
          HStack {
            Spacer()
            Label(addButtonTitle, systemImage: "plus.circle")
            Spacer()
          }
        }
      }

      if mode == .management, isLoggedIn {
        Section {
          Button(role: .destructive) {
            showLogoutAlert = true
          } label: {
            HStack {
              Spacer()
              Label(String(localized: "Logout"), systemImage: "rectangle.portrait.and.arrow.right")
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
    .toolbar {
      if mode == .onboarding {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
          }
        }
      }
    }
    .sheet(item: $editingInstance) { instance in
      SettingsServerEditView(instance: instance)
    }
    .alert(
      String(localized: "Delete Server"),
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
      Button(String(localized: "Delete"), role: .destructive) {
        delete(instance)
      }
      Button(String(localized: "Cancel"), role: .cancel) {}
    } message: { instance in
      Text(
        String(
          localized:
            "This will remove \(instance.name), its credentials, and all cached data for this server."
        )
      )
    }
    .alert(String(localized: "Logout"), isPresented: $showLogoutAlert) {
      Button(String(localized: "Cancel"), role: .cancel) {}
      Button(String(localized: "Logout"), role: .destructive) {
        authViewModel.logout()
      }
    } message: {
      Text(String(localized: "Are you sure you want to logout?"))
    }
    .sheet(isPresented: $showLogin) {
      SheetView(title: String(localized: "Connect to a Server"), size: .large) {
        LoginView()
      }
    }
    .onChange(of: isLoggedIn) { _, loggedIn in
      if loggedIn && mode == .onboarding {
        dismiss()
      }
    }
  }

  private var navigationTitle: String {
    switch mode {
    case .management:
      return String(localized: "Servers")
    case .onboarding:
      return String(localized: "Get Started")
    }
  }

  @ViewBuilder
  private var introHeader: some View {
    switch mode {
    case .management:
      EmptyView()
    case .onboarding:
      Text(String(localized: "Choose an existing Komga server or add a new one to begin."))
        .font(.subheadline)
        .textCase(nil)
        .padding(.vertical)
    }
  }

  private var footerText: some View {
    Text("Credentials are stored locally so you can switch servers without re-entering them.")
      .foregroundStyle(.secondary)
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

  private var addButtonTitle: LocalizedStringKey {
    switch mode {
    case .management:
      return "Add Another Server"
    case .onboarding:
      return "Connect to a Server"
    }
  }

  private func isActive(_ instance: KomgaInstance) -> Bool {
    activeInstanceId == instance.id.uuidString
  }

  private func isSwitching(_ instance: KomgaInstance) -> Bool {
    authViewModel.isSwitching && authViewModel.switchingInstanceId == instance.id.uuidString
  }

  private func switchTo(_ instance: KomgaInstance) {
    guard !isActive(instance) else { return }
    Task {
      let success = await authViewModel.switchTo(instance: instance)
      if success {
        instance.lastUsedAt = Date()
        saveChanges()
      }
    }
  }

  private func delete(_ instance: KomgaInstance) {
    if isActive(instance) {
      authViewModel.logout()
    }
    // Clear libraries (sync)
    let instanceId = instance.id.uuidString
    LibraryManager.shared.removeLibraries(for: instanceId)
    modelContext.delete(instance)
    saveChanges()
    instancePendingDeletion = nil

    // Clear SwiftData entities and offline data (async)
    Task {
      await SyncService.shared.clearInstanceData(instanceId: instanceId)
      await OfflineManager.shared.cancelAllDownloads()
      OfflineManager.removeOfflineData(for: instanceId)
      CacheManager.clearCaches(instanceId: instanceId)
    }
  }

  private func saveChanges() {
    do {
      try modelContext.save()
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

}
