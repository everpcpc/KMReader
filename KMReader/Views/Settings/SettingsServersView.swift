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
  @Environment(\.colorScheme) private var colorScheme
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
          .padding(.vertical, 16)
          .listRowBackground(Color.clear)
        } else {
          ForEach(instances) { instance in
            serverRow(for: instance)
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

  private var introText: String? {
    switch mode {
    case .management:
      return nil
    case .onboarding:
      return String(localized: "Choose an existing Komga server or add a new one to begin.")
    }
  }

  private var footerText: some View {
    Text(
      String(
        localized:
          "Credentials are stored locally so you can switch servers without re-entering them."
      )
    )
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

  private func serverRow(for instance: KomgaInstance) -> some View {
    let active = isActive(instance)
    return Button {
      withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
        switchTo(instance)
      }
    } label: {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .center, spacing: 12) {
          serverAvatar(isActive: active, isAdmin: instance.isAdmin)
          VStack(alignment: .leading, spacing: 4) {
            Text(instance.displayName)
              .font(.headline)
              .foregroundStyle(.primary)
            Text(instance.serverURL)
              .font(.footnote)
              .lineLimit(1)
              .minimumScaleFactor(0.85)
              .foregroundStyle(.secondary)
          }
          Spacer(minLength: 8)
          statusView(for: instance, isActive: active)
        }

        Divider()
          .opacity(0.15)

        VStack(alignment: .leading, spacing: 10) {
          infoDetailRow(icon: "envelope.fill", text: instance.username)
          infoDetailRow(
            icon: instance.isAdmin ? "shield.checkered" : "shield.fill",
            text: instance.isAdmin
              ? String(localized: "Admin Access") : String(localized: "User Access"),
            textColor: instance.isAdmin ? .green : .secondary
          )
          infoDetailRow(
            icon: "key.fill",
            text: instance.resolvedAuthMethod == .apiKey
              ? String(localized: "API Key") : String(localized: "Username & Password"),
            textColor: .secondary
          )
          infoDetailRow(
            icon: "clock.arrow.circlepath", text: lastUsedDescription(for: instance),
            textColor: .secondary)
        }
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(cardBackground(isActive: active))
    }
    .animation(.easeInOut(duration: 0.25), value: active)
    .adaptiveButtonStyle(.plain)
    .disabled(active || authViewModel.isSwitching)
    #if os(iOS) || os(macOS)
      .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
      .listRowSeparator(.hidden)
    #endif
    #if os(iOS) || os(macOS)
      .swipeActions(edge: .trailing) {
        if !isActive(instance) {
          Button {
            editingInstance = instance
          } label: {
            Label(String(localized: "Edit"), systemImage: "pencil")
          }

          Button(role: .destructive) {
            instancePendingDeletion = instance
          } label: {
            Label(String(localized: "Delete"), systemImage: "trash")
          }
        }
      }
    #endif
    .contextMenu {
      if !isActive(instance) {
        Button {
          editingInstance = instance
        } label: {
          Label(String(localized: "Edit"), systemImage: "pencil")
        }

        Button(role: .destructive) {
          instancePendingDeletion = instance
        } label: {
          Label(String(localized: "Delete"), systemImage: "trash")
        }
      }
    }
  }

  private func isActive(_ instance: KomgaInstance) -> Bool {
    activeInstanceId == instance.id.uuidString
  }

  private func isSwitching(_ instance: KomgaInstance) -> Bool {
    authViewModel.isSwitching && authViewModel.switchingInstanceId == instance.id.uuidString
  }

  @ViewBuilder
  private func statusView(for instance: KomgaInstance, isActive: Bool) -> some View {
    if isSwitching(instance) {
      ProgressView()
        .scaleEffect(0.85)
    } else if isActive {
      infoTag(
        icon: "checkmark.seal.fill", text: LocalizedStringKey("Active"), tint: themeColor.color,
        textColor: themeColor.color)
    } else {
      Image(systemName: "chevron.right")
        .font(.body.weight(.semibold))
        .foregroundStyle(.secondary)
    }
  }

  private func infoTag(
    icon: String,
    text: LocalizedStringKey,
    tint: Color = .secondary,
    textColor: Color? = nil,
    fillOpacity: Double = 0.16
  ) -> some View {
    HStack(spacing: 4) {
      Image(systemName: icon)
      Text(text)
    }
    .font(.caption.weight(.medium))
    .foregroundStyle(textColor ?? tint)
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(
      Capsule(style: .continuous)
        .fill(tint.opacity(fillOpacity))
    )
  }

  private func infoDetailRow(icon: String, text: String, textColor: Color = .primary) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: icon)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(width: 16)
      Text(text)
        .font(.footnote)
        .foregroundStyle(textColor)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func serverAvatar(isActive: Bool, isAdmin: Bool) -> some View {
    let gradientColors: [Color]
    if isActive {
      gradientColors = [
        themeColor.color.opacity(0.85),
        themeColor.color.opacity(0.55),
      ]
    } else if colorScheme == .dark {
      gradientColors = [
        Color.white.opacity(0.12),
        Color.white.opacity(0.05),
      ]
    } else {
      gradientColors = [
        Color.black.opacity(0.08),
        Color.black.opacity(0.02),
      ]
    }

    return ZStack {
      Circle()
        .fill(
          LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .overlay(
          Circle()
            .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.2), lineWidth: 1)
        )

      Image(systemName: isAdmin ? "crown.fill" : "server.rack")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(isActive ? Color.white : Color.primary)
    }
    .frame(width: 46, height: 46)
  }

  private func lastUsedDescription(for instance: KomgaInstance) -> String {
    let relativeText = instance.lastUsedAt.formatted(
      .relative(presentation: .named, unitsStyle: .abbreviated))
    return String(localized: "Last used \(relativeText)")
  }

  private func cardBackground(isActive: Bool) -> some View {
    let inactiveTop = colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    let inactiveBottom =
      colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.02)
    let colors =
      isActive
      ? [
        themeColor.color.opacity(0.45),
        themeColor.color.opacity(0.2),
      ]
      : [
        inactiveTop,
        inactiveBottom,
      ]

    return RoundedRectangle(cornerRadius: 22, style: .continuous)
      .fill(
        LinearGradient(
          colors: colors,
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .strokeBorder(
            isActive ? themeColor.color.opacity(0.6) : Color.primary.opacity(0.05),
            lineWidth: isActive ? 2 : 1
          )
      )
      .shadow(
        color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08),
        radius: isActive ? 12 : 6,
        x: 0,
        y: isActive ? 6 : 3
      )
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
    modelContext.delete(instance)
    saveChanges()
    instancePendingDeletion = nil

    let instanceId = instance.id.uuidString

    // Clear SwiftData entities
    LibraryManager.shared.removeLibraries(for: instanceId)
    SyncService.shared.clearInstanceData(instanceId: instanceId)

    // Clear offline downloads and caches (async)
    Task {
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
