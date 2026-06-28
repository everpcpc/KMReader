//
// DashboardView.swift
//
//

import SwiftUI

struct DashboardView: View {
  let authViewModel: AuthViewModel
  let readerPresentation: ReaderPresentationManager

  @State private var isRefreshing = false
  @State private var showLibraryPicker = false
  @State private var isCheckingConnection = false
  @State private var offlineQueueingSections: Set<DashboardSection> = []

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("enableSSEAutoRefresh") private var enableSSEAutoRefresh: Bool = true
  @AppStorage("enableSSE") private var enableSSE: Bool = true
  @AppStorage("isOffline") private var isOffline: Bool = false
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue

  private let sseService = SSEService.shared
  private let sectionCacheStore = DashboardSectionCacheStore.shared
  private let logger = AppLogger(.dashboard)

  private var gridDensityBinding: Binding<GridDensity> {
    Binding(
      get: { GridDensity.closest(to: gridDensity) },
      set: { gridDensity = $0.rawValue }
    )
  }

  private var isQueueingDashboardOffline: Bool {
    !offlineQueueingSections.isEmpty
  }

  private var showsBrowseSearchButton: Bool {
    #if os(macOS)
      return true
    #elseif os(iOS)
      return PlatformHelper.isPad
    #else
      return false
    #endif
  }

  @ViewBuilder
  private var browseSearchButton: some View {
    if showsBrowseSearchButton {
      NavigationLink(value: NavDestination.browseSearch) {
        Image(systemName: "magnifyingglass")
      }
      .help(String(localized: "Search"))
      .accessibilityLabel(String(localized: "Search"))
    }
  }

  @ViewBuilder
  private var dashboardHeader: some View {
    HStack {
      #if os(tvOS)
        Button {
          showLibraryPicker = true
        } label: {
          Label(String(localized: "Libraries"), systemImage: ContentIcon.library)
        }
      #endif

      if enableSSE {
        #if os(tvOS)
          if isOffline {
            Button {
              Task {
                await tryReconnect()
              }
            } label: {
              if isCheckingConnection {
                LoadingIcon()
              } else {
                Label(String(localized: "settings.offline"), systemImage: "wifi.slash")
                  .foregroundStyle(.orange)
              }
            }
            .disabled(isCheckingConnection)
          } else {
            Button {
              Task {
                await refreshDashboard(reason: "Manual tvOS button")
              }
            } label: {
              Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshing)
          }
        #endif
        ServerUpdateStatusView()
      }
      Spacer()
    }
    .padding()
  }

  @MainActor
  private func refreshDashboard(reason: String) async {
    logger.debug("Dashboard refresh requested: \(reason)")

    // Update last event time for manual refreshes
    AppConfig.serverLastUpdate = Date()

    // Check SSE connection status and reconnect if disconnected
    if enableSSE {
      await SSEService.shared.connect()
    }

    withAnimation {
      isRefreshing = true
    }
    await DashboardSectionRefreshNotifier.postAll(source: .manual, reason: reason)
    try? await Task.sleep(nanoseconds: 2_000_000_000)
    withAnimation {
      isRefreshing = false
    }
  }

  private func handleSSEEvent(_ info: SSEEventInfo) {
    switch info.type {
    case .libraryAdded, .libraryChanged, .libraryDeleted:
      Task {
        await DashboardSectionRefreshNotifier.postAll(
          source: .auto,
          reason: "SSE \(info.type.rawValue)"
        )
      }
    default:
      break
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        #if os(tvOS)
          dashboardHeader
        #else
          if enableSSE {
            dashboardHeader
          }
        #endif

        ForEach(dashboard.sections, id: \.id) { section in
          if section.isLocalSection {
            DashboardPinnedSectionView(section: section)
          } else {
            DashboardSectionView(section: section)
          }
        }
      }
      .padding(.vertical)
    }
    .inlineNavigationBarTitle(String(localized: "title.dashboard"))
    .onChange(of: authViewModel.isSwitching) { oldValue, newValue in
      // Refresh when server switch completes (transitions from switching to not switching)
      // This avoids race condition where refresh happens after logout but before new auth is ready
      if oldValue && !newValue {
        Task {
          await refreshDashboard(reason: "Server switch completed")
        }
      }
    }
    .onChange(of: dashboard.libraryIds) { _, _ in
      // Skip during server switch - dedicated refresh happens when switch completes
      guard !authViewModel.isSwitching else { return }
      // Bypass auto-refresh setting for configuration changes
      Task {
        await refreshDashboard(reason: "Library filter changed")
      }
      WidgetDataService.refreshWidgetData()
    }
    .task {
      DashboardRefreshCoordinator.shared.configure(
        autoRefreshEnabled: enableSSEAutoRefresh
      )
    }
    .onReceive(NotificationCenter.default.publisher(for: .sseEventReceived)) { notification in
      guard let info = notification.userInfo?["info"] as? SSEEventInfo else { return }
      handleSSEEvent(info)
    }
    .onChange(of: enableSSEAutoRefresh) { _, newValue in
      DashboardRefreshCoordinator.shared.setAutoRefreshEnabled(newValue)
    }
    #if os(iOS) || os(macOS)
      .toolbar {
        #if os(macOS)
          ToolbarItem(placement: .navigation) {
            Button {
              showLibraryPicker = true
            } label: {
              Image(systemName: ContentIcon.library)
            }
          }
        #else
          ToolbarItem(placement: .cancellationAction) {
            Button {
              showLibraryPicker = true
            } label: {
              Image(systemName: ContentIcon.library)
            }
          }
        #endif

        ToolbarItemGroup(placement: .confirmationAction) {
          browseSearchButton

          if isOffline {
            Button {
              Task {
                await tryReconnect()
              }
            } label: {
              if isCheckingConnection {
                LoadingIcon()
              } else {
                Image(systemName: "wifi.slash")
                .foregroundStyle(.red)
              }
            }
            .disabled(isCheckingConnection)
            .help(String(localized: "Check Server Connection"))
            .accessibilityLabel(String(localized: "Check Server Connection"))
          } else if isRefreshing {
            Button {
            } label: {
              LoadingIcon()
            }
          } else {
            Menu {
              Picker(selection: gridDensityBinding) {
                ForEach(GridDensity.allCases, id: \.self) { density in
                  Text(density.label).tag(density)
                }
              } label: {
                Label(
                  String(localized: "settings.appearance.gridDensity.label"),
                  systemImage: GridDensity.icon
                )
              }.pickerStyle(.menu)

              Divider()

              Menu {
                ForEach(DashboardSection.latestOfflineQueueSections) { section in
                  Button {
                    queueDashboardSectionOffline(section)
                  } label: {
                    Label(
                      section.displayName,
                      systemImage: section.icon
                    )
                  }
                  .disabled(isQueueingDashboardOffline)
                }
              } label: {
                Label(
                  String(localized: "dashboard.downloadLatest", defaultValue: "Download Latest"),
                  systemImage: "arrow.down.circle"
                )
              }
              .disabled(isOffline || isQueueingDashboardOffline)

              Divider()

              Button {
                Task {
                  await refreshDashboard(reason: "Manual toolbar button")
                }
              } label: {
                Label(String(localized: "Refresh Dashboard"), systemImage: "arrow.clockwise")
              }

              Divider()

              Button {
                enterOfflineMode()
              } label: {
                Label(String(localized: "Enter Offline Mode"), systemImage: "wifi.slash")
              }
            } label: {
              Image(systemName: "ellipsis")
            }
          }
        }
      }
      .refreshable {
        await refreshDashboard(reason: "Pull to refresh")
      }
      .sheet(isPresented: $showLibraryPicker) {
        LibraryPickerSheet()
      }
    #endif
    #if os(tvOS)
      .sheet(isPresented: $showLibraryPicker) {
        LibraryPickerSheet()
      }
    #endif
  }

  private func tryReconnect() async {
    withAnimation {
      isCheckingConnection = true
    }
    let serverReachable = await authViewModel.loadCurrentUser()
    let reconnected = serverReachable && AppConfig.isLoggedIn
    if reconnected {
      AppConfig.exitOfflineMode()
    }
    // If unreachable: stay in current offline mode. We deliberately do not call
    // `enterAutoOfflineMode()` here — the user invoked the reconnect manually
    // from a state that may have been either auto or manual, and a failed retry
    // should preserve that classification rather than reclassifying as auto.
    withAnimation {
      isCheckingConnection = false
    }

    if reconnected {
      await sseService.connect()
      ErrorManager.shared.notify(message: String(localized: "settings.connection_restored"))
      await refreshDashboard(reason: "Reconnected")
    }
  }

  private func queueDashboardSectionOffline(_ section: DashboardSection) {
    guard section.supportsDownloadLatest, !current.instanceId.isEmpty, !isOffline else { return }
    guard !offlineQueueingSections.contains(section) else { return }

    withAnimation {
      _ = offlineQueueingSections.insert(section)
    }
    let instanceId = current.instanceId
    let libraryIds = dashboard.libraryIds

    Task {
      defer {
        Task { @MainActor in
          withAnimation {
            offlineQueueingSections.remove(section)
          }
        }
      }

      do {
        let ids = try await bookIdsForOfflineQueue(section: section, libraryIds: libraryIds)
        guard !ids.isEmpty else {
          ErrorManager.shared.notify(
            message: String(localized: "No books found to queue for offline reading.")
          )
          return
        }

        let queuedCount =
          await DatabaseOperator.databaseIfConfigured()?.queueBooksOffline(
            bookIds: ids,
            instanceId: instanceId
          ) ?? 0

        if queuedCount > 0 {
          OfflineManager.shared.triggerSync(instanceId: instanceId)
          ErrorManager.shared.notify(
            message: String(
              format: String(localized: "Queued %lld books for offline reading."),
              Int64(queuedCount)
            )
          )
        } else {
          ErrorManager.shared.notify(
            message: String(localized: "No new books were added to the offline queue.")
          )
        }
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func bookIdsForOfflineQueue(
    section: DashboardSection,
    libraryIds: [String]
  ) async throws -> [String] {
    let cachedIds = sectionCacheStore.ids(for: section)
    if !cachedIds.isEmpty {
      return cachedIds
    }

    guard
      let page = try await section.fetchBooks(
        libraryIds: libraryIds,
        page: 0,
        size: 20
      )
    else {
      return []
    }

    let ids = page.content.map(\.id)
    _ = sectionCacheStore.updateIfChanged(section: section, ids: ids)
    return ids
  }

  private func enterOfflineMode() {
    guard !isOffline else { return }

    DashboardRefreshCoordinator.shared.cancelPendingAutoRefresh(clearDeferred: true)
    AppConfig.enterManualOfflineMode()

    Task {
      await sseService.disconnect(notify: false)
    }
  }
}
