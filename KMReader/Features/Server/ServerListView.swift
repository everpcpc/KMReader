//
// ServerListView.swift
//
//

import Dependencies
import SQLiteData
import SwiftUI

struct ServerListView: View {
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
  @Dependency(\.defaultDatabase) private var database
  @FetchAll(KomgaInstanceRecord.order { $0.lastUsedAt.desc() }) private var instances: [KomgaInstanceRecord]
  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("isLoggedInV2") private var isLoggedIn: Bool = false

  @State private var instancePendingDeletion: KomgaInstanceRecord?
  @State private var editingInstance: KomgaInstanceRecord?
  @State private var showLogin = false
  @State private var showLogoutAlert = false

  private var activeInstanceId: String? {
    current.instanceId.isEmpty ? nil : current.instanceId
  }

  private var sortedInstances: [KomgaInstanceRecord] {
    instances.sorted {
      if $0.lastUsedAt == $1.lastUsedAt {
        return $0.name.localizedStandardCompare($1.name) == .orderedAscending
      }
      return $0.lastUsedAt > $1.lastUsedAt
    }
  }

  var body: some View {
    Form {
      Section(header: introHeader, footer: footerText) {
        if sortedInstances.isEmpty {
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
          ForEach(sortedInstances) { instance in
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
            // .tvFocusableHighlight()
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
    .sheet(item: $editingInstance) { instance in
      ServerEditView(instance: instance)
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
        ErrorManager.shared.notify(message: String(localized: "notification.auth.loggedOut"))
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

  private func isActive(_ instance: KomgaInstanceRecord) -> Bool {
    activeInstanceId == instance.id.uuidString
  }

  private func isSwitching(_ instance: KomgaInstanceRecord) -> Bool {
    authViewModel.isSwitching && authViewModel.switchingInstanceId == instance.id.uuidString
  }

  private func switchTo(_ instance: KomgaInstanceRecord) {
    guard !isActive(instance) else { return }
    Task {
      let success = await authViewModel.switchTo(record: instance)
      if success {
        do {
          let now = Date()
          try await database.write { db in
            try KomgaInstanceRecord
              .find(instance.id)
              .update {
                $0.lastUsedAt = #bind(now)
              }
              .execute(db)
          }
        } catch {
          ErrorManager.shared.alert(error: error)
        }
      }
    }
  }

  private func delete(_ instance: KomgaInstanceRecord) {
    if isActive(instance) {
      authViewModel.logout()
    }
    // Clear libraries (sync)
    let instanceId = instance.id.uuidString
    LibraryManager.shared.removeLibraries(for: instanceId)
    do {
      try database.write { db in
        try KomgaInstanceRecord.find(instance.id).delete().execute(db)
      }
    } catch {
      ErrorManager.shared.alert(error: error)
      return
    }
    ErrorManager.shared.notify(message: String(localized: "notification.server.deleted"))
    instancePendingDeletion = nil

    // Clear SwiftData entities and offline data (async)
    Task {
      await SyncService.shared.clearInstanceData(instanceId: instanceId)
      await OfflineManager.shared.cancelAllDownloads()
      OfflineManager.removeOfflineData(for: instanceId)
      CacheManager.clearCaches(instanceId: instanceId)
    }
  }

}
