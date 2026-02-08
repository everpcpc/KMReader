//
//  DashboardView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Combine
import OSLog
import SwiftUI

struct DashboardView: View {
  @State private var refreshTrigger = DashboardRefreshTrigger(id: UUID(), source: .manual)
  @State private var isRefreshing = false
  @State private var pendingRefreshTask: Task<Void, Never>?
  @State private var readerCloseRefreshTask: Task<Void, Never>?
  @State private var showLibraryPicker = false
  @State private var shouldRefreshAfterReading = false
  @State private var isCheckingConnection = false

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("enableSSEAutoRefresh") private var enableSSEAutoRefresh: Bool = true
  @AppStorage("enableSSE") private var enableSSE: Bool = true
  @AppStorage("isOffline") private var isOffline: Bool = false
  @AppStorage("gridDensity") private var gridDensity: Double = GridDensity.standard.rawValue

  @Environment(ReaderPresentationManager.self) private var readerPresentation
  @Environment(AuthViewModel.self) private var authViewModel

  private let sseService = SSEService.shared
  private let debounceInterval: TimeInterval = 5.0  // 5 seconds debounce
  private let logger = AppLogger(.dashboard)

  private var isReaderActive: Bool {
    readerPresentation.readerState != nil
  }

  private var gridDensityBinding: Binding<GridDensity> {
    Binding(
      get: { GridDensity.closest(to: gridDensity) },
      set: { gridDensity = $0.rawValue }
    )
  }

  private func performRefresh(reason: String, source: DashboardRefreshSource) {
    logger.debug("Dashboard refresh start: \(reason)")

    // Update refresh trigger to cause all sections to reload
    refreshTrigger = DashboardRefreshTrigger(id: UUID(), source: source)
    isRefreshing = true
    Task {
      // Wait for 2 seconds to allow any pending refreshes to complete
      try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
      isRefreshing = false
    }
  }

  private func refreshSections(_ sections: Set<DashboardSection>, reason: String) {
    logger.debug("Dashboard partial refresh: \(reason)")
    refreshTrigger = DashboardRefreshTrigger(
      id: UUID(),
      source: .manual,
      sectionsToRefresh: sections
    )
  }

  private func refreshDashboard(reason: String) {
    logger.debug("Dashboard refresh requested: \(reason)")

    // Cancel any pending debounced refresh
    pendingRefreshTask?.cancel()
    pendingRefreshTask = nil
    shouldRefreshAfterReading = false

    // Update last event time for manual refreshes
    AppConfig.serverLastUpdate = Date()

    // Check SSE connection status and reconnect if disconnected
    if enableSSE {
      Task {
        await SSEService.shared.connect()
      }
    }

    // Perform refresh immediately
    performRefresh(reason: reason, source: .manual)
  }

  private func scheduleRefresh(reason: String) {
    // Skip if auto-refresh is disabled
    guard enableSSEAutoRefresh else { return }

    logger.debug("Dashboard auto-refresh scheduled: \(reason)")

    // Cancel any existing pending refresh
    pendingRefreshTask?.cancel()
    pendingRefreshTask = nil

    // Defer refresh while actively reading
    if isReaderActive {
      shouldRefreshAfterReading = true
      AppConfig.serverLastUpdate = Date()
      return
    }

    // Record latest event time immediately
    AppConfig.serverLastUpdate = Date()

    // Schedule a new refresh after debounce interval
    // This ensures the last event will always trigger a refresh
    pendingRefreshTask = Task {
      do {
        try await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
      } catch {
        // Task cancelled
        return
      }

      // Check if task was cancelled
      guard !Task.isCancelled else { return }

      // Perform the refresh
      await MainActor.run {
        if isReaderActive {
          shouldRefreshAfterReading = true
        } else {
          logger.debug("Executing scheduled refresh: \(reason)")
          performRefresh(reason: "Auto after debounce: \(reason)", source: .auto)
        }
        pendingRefreshTask = nil
      }
    }
  }

  private func handleSSEEvent(_ info: SSEEventInfo) {
    let jsonData = info.data.data(using: .utf8) ?? Data()
    let decoder = JSONDecoder()

    switch info.type {
    case .seriesAdded, .seriesChanged, .seriesDeleted:
      if let event = try? decoder.decode(SeriesSSEDto.self, from: jsonData) {
        if shouldRefreshForLibrary(event.libraryId) {
          scheduleRefresh(reason: "SSE \(info.type.rawValue) \(event.seriesId)")
        }
      }
    case .bookAdded, .bookChanged, .bookDeleted:
      if let event = try? decoder.decode(BookSSEDto.self, from: jsonData) {
        if shouldRefreshForLibrary(event.libraryId) {
          scheduleRefresh(reason: "SSE \(info.type.rawValue) \(event.bookId)")
        }
      }
    case .readProgressChanged, .readProgressDeleted, .readProgressSeriesChanged,
      .readProgressSeriesDeleted:
      scheduleRefresh(reason: "SSE \(info.type.rawValue)")
    case .libraryAdded, .libraryChanged, .libraryDeleted:
      scheduleRefresh(reason: "SSE \(info.type.rawValue)")
    case .collectionAdded, .collectionChanged, .collectionDeleted:
      scheduleRefresh(reason: "SSE \(info.type.rawValue)")
    case .readListAdded, .readListChanged, .readListDeleted:
      scheduleRefresh(reason: "SSE \(info.type.rawValue)")
    default:
      break
    }
  }

  private func shouldRefreshForLibrary(_ libraryId: String) -> Bool {
    // If dashboard shows all libraries (empty array), refresh for any library
    // Otherwise, only refresh if the library matches
    return dashboard.libraryIds.isEmpty || dashboard.libraryIds.contains(libraryId)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        HStack {
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
                  refreshDashboard(reason: "Manual tvOS button")
                } label: {
                  Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)
              }
            #endif
            ServerUpdateStatusView()
          }
          Spacer()
        }.padding()

        ForEach(dashboard.sections, id: \.id) { section in
          DashboardSectionView(
            section: section,
            refreshTrigger: refreshTrigger
          )
        }
      }
      .padding(.vertical)
    }
    .inlineNavigationBarTitle(String(localized: "title.dashboard"))
    .animation(.default, value: dashboard)
    .onChange(of: authViewModel.isSwitching) { oldValue, newValue in
      // Refresh when server switch completes (transitions from switching to not switching)
      // This avoids race condition where refresh happens after logout but before new auth is ready
      if oldValue && !newValue {
        refreshDashboard(reason: "Server switch completed")
      }
    }
    .onChange(of: dashboard.libraryIds) { _, _ in
      // Skip during server switch - dedicated refresh happens when switch completes
      guard !authViewModel.isSwitching else { return }
      // Bypass auto-refresh setting for configuration changes
      refreshDashboard(reason: "Library filter changed")
    }
    .onDisappear {
      // Cancel any pending refresh when view disappears
      pendingRefreshTask?.cancel()
      pendingRefreshTask = nil
      readerCloseRefreshTask?.cancel()
      readerCloseRefreshTask = nil
    }
    .onReceive(NotificationCenter.default.publisher(for: .sseEventReceived)) { notification in
      guard let info = notification.userInfo?["info"] as? SSEEventInfo else { return }
      handleSSEEvent(info)
    }
    .onChange(of: enableSSEAutoRefresh) { _, newValue in
      // Cancel any pending refresh when auto-refresh is disabled
      if !newValue {
        pendingRefreshTask?.cancel()
        pendingRefreshTask = nil
      }
    }
    .onChange(of: readerPresentation.readerState) { _, newState in
      if newState != nil {
        // Reader opened - cancel any pending dashboard refresh
        pendingRefreshTask?.cancel()
        pendingRefreshTask = nil
        readerCloseRefreshTask?.cancel()
        readerCloseRefreshTask = nil
      } else {
        let needsFullRefresh = shouldRefreshAfterReading
        shouldRefreshAfterReading = false
        let visitedBookIds = readerPresentation.visitedBookIds

        readerCloseRefreshTask?.cancel()
        readerCloseRefreshTask = Task {
          logger.debug(
            "Dashboard waiting for reader progress flush before refresh: books=\(visitedBookIds.count), fullRefresh=\(needsFullRefresh)"
          )

          if !visitedBookIds.isEmpty {
            try? await Task.sleep(for: .milliseconds(200))
            let idle = await ReaderProgressTracker.shared.waitUntilIdle(
              bookIds: visitedBookIds,
              timeout: .seconds(2)
            )
            if !idle {
              logger.warning(
                "Dashboard refresh wait timed out, continuing with close refresh"
              )
            }
          }

          guard !Task.isCancelled else { return }

          await MainActor.run {
            if needsFullRefresh {
              refreshDashboard(reason: "Deferred after reader closed")
            } else {
              refreshSections([.keepReading, .onDeck, .recentlyReadBooks], reason: "Reader closed")
            }
            readerCloseRefreshTask = nil
          }
        }
      }
    }
    #if !os(tvOS)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            showLibraryPicker = true
          } label: {
            Image(systemName: ContentIcon.library)
          }
        }

        ToolbarItem(placement: .confirmationAction) {
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

              Button {
                refreshDashboard(reason: "Manual toolbar button")
              } label: {
                Label(String(localized: "Refresh Dashboard"), systemImage: "arrow.clockwise")
              }
            } label: {
              Image(systemName: "ellipsis")
            }
            .appMenuStyle()
          }
        }
      }
      .refreshable {
        refreshDashboard(reason: "Pull to refresh")
      }
      .sheet(isPresented: $showLibraryPicker) {
        LibraryPickerSheet()
      }
    #endif
  }

  private func tryReconnect() async {
    isCheckingConnection = true
    let serverReachable = await authViewModel.loadCurrentUser()
    isOffline = !serverReachable
    isCheckingConnection = false

    if serverReachable {
      await sseService.connect()
      ErrorManager.shared.notify(message: String(localized: "settings.connection_restored"))
      refreshDashboard(reason: "Reconnected")
    }
  }
}
