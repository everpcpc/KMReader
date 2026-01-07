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
  @State private var isRefreshDisabled = false
  @State private var pendingRefreshTask: Task<Void, Never>?
  @State private var showLibraryPicker = false
  @State private var shouldRefreshAfterReading = false
  @State private var isCheckingConnection = false

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @AppStorage("enableSSEAutoRefresh") private var enableSSEAutoRefresh: Bool = true
  @AppStorage("enableSSE") private var enableSSE: Bool = true
  @AppStorage("isOffline") private var isOffline: Bool = false

  @Environment(ReaderPresentationManager.self) private var readerPresentation
  @Environment(AuthViewModel.self) private var authViewModel

  private let sseService = SSEService.shared
  private let debounceInterval: TimeInterval = 5.0  // 5 seconds debounce - wait for events to settle
  private let logger = AppLogger(.dashboard)

  private func performRefresh(reason: String, source: DashboardRefreshSource) {
    logger.debug("Dashboard refresh start: \(reason)")

    // Update refresh trigger to cause all sections to reload
    refreshTrigger = DashboardRefreshTrigger(id: UUID(), source: source)
    isRefreshDisabled = true
    Task {
      try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
      isRefreshDisabled = false
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
    if enableSSE && !sseService.connected {
      sseService.connect()
    }

    // Perform refresh immediately
    performRefresh(reason: reason, source: .manual)
  }

  private func scheduleRefresh(reason: String) {
    logger.debug("Dashboard auto-refresh scheduled: \(reason)")

    // Skip if auto-refresh is disabled
    guard enableSSEAutoRefresh else { return }

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
      try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))

      // Check if task was cancelled
      guard !Task.isCancelled else { return }

      // Perform the refresh
      await MainActor.run {
        if isReaderActive {
          shouldRefreshAfterReading = true
        } else {
          performRefresh(reason: "Auto after debounce: \(reason)", source: .auto)
        }
        pendingRefreshTask = nil
      }
    }
  }

  private func shouldRefreshForLibrary(_ libraryId: String) -> Bool {
    // If dashboard shows all libraries (empty array), refresh for any library
    // Otherwise, only refresh if the library matches
    return dashboard.libraryIds.isEmpty || dashboard.libraryIds.contains(libraryId)
  }

  private var isReaderActive: Bool {
    readerPresentation.readerState != nil
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
                    ProgressView()
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
                  Label("Refresh", systemImage: "arrow.clockwise.circle")
                }
                .disabled(isRefreshDisabled)
              }
            #endif
            ServerUpdateStatusView()
          }
          Spacer()
        }.padding()

        ForEach(dashboard.sections, id: \.id) { section in
          if section.isLocalSection {
            DashboardLocalSectionView(
              section: section,
              refreshTrigger: refreshTrigger
            )
          } else {
            DashboardSectionView(
              section: section,
              refreshTrigger: refreshTrigger
            )
          }
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
      // Bypass auto-refresh setting for configuration changes
      refreshDashboard(reason: "Library filter changed")
    }
    .onAppear {
      setupSSEHandlers()
    }
    .onDisappear {
      cleanupSSEHandlers()
      // Cancel any pending refresh when view disappears
      pendingRefreshTask?.cancel()
      pendingRefreshTask = nil
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
      } else if shouldRefreshAfterReading {
        // Check if there's a pending refresh
        shouldRefreshAfterReading = false
        refreshDashboard(reason: "Deferred after reader closed")
      } else {
        // Refresh sections when reader is closed otherwise
        refreshSections([.keepReading, .onDeck, .recentlyReadBooks], reason: "Reader closed")
      }
    }
    #if !os(tvOS)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            showLibraryPicker = true
          } label: {
            Image(systemName: "books.vertical.circle")
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
                ProgressView()
              } else {
                Image(systemName: "wifi.slash")
                .foregroundStyle(.red)
              }
            }
            .disabled(isCheckingConnection)
          } else {
            Button {
              refreshDashboard(reason: "Manual toolbar button")
            } label: {
              Image(systemName: "arrow.clockwise.circle")
            }
            .disabled(isRefreshDisabled)
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

  private func setupSSEHandlers() {
    // Series events
    sseService.onSeriesAdded = { event in
      if shouldRefreshForLibrary(event.libraryId) {
        scheduleRefresh(reason: "SSE SeriesAdded \(event.seriesId)")
      }
    }
    sseService.onSeriesChanged = { event in
      if shouldRefreshForLibrary(event.libraryId) {
        scheduleRefresh(reason: "SSE SeriesChanged \(event.seriesId)")
      }
    }
    sseService.onSeriesDeleted = { event in
      if shouldRefreshForLibrary(event.libraryId) {
        scheduleRefresh(reason: "SSE SeriesDeleted \(event.seriesId)")
      }
    }

    // Book events
    sseService.onBookAdded = { event in
      if shouldRefreshForLibrary(event.libraryId) {
        scheduleRefresh(reason: "SSE BookAdded \(event.bookId)")
      }
    }
    sseService.onBookChanged = { event in
      if shouldRefreshForLibrary(event.libraryId) {
        scheduleRefresh(reason: "SSE BookChanged \(event.bookId)")
      }
    }
    sseService.onBookDeleted = { event in
      if shouldRefreshForLibrary(event.libraryId) {
        scheduleRefresh(reason: "SSE BookDeleted \(event.bookId)")
      }
    }

    // Read progress events - always refresh as they affect multiple sections
    sseService.onReadProgressChanged = { _ in
      scheduleRefresh(reason: "SSE ReadProgressChanged")
    }
    sseService.onReadProgressDeleted = { _ in
      scheduleRefresh(reason: "SSE ReadProgressDeleted")
    }
    sseService.onReadProgressSeriesChanged = { _ in
      scheduleRefresh(reason: "SSE ReadProgressSeriesChanged")
    }
    sseService.onReadProgressSeriesDeleted = { _ in
      scheduleRefresh(reason: "SSE ReadProgressSeriesDeleted")
    }
  }

  private func cleanupSSEHandlers() {
    // Clear handlers to avoid memory leaks
    sseService.onSeriesAdded = nil
    sseService.onSeriesChanged = nil
    sseService.onSeriesDeleted = nil
    sseService.onBookAdded = nil
    sseService.onBookChanged = nil
    sseService.onBookDeleted = nil
    sseService.onReadProgressChanged = nil
    sseService.onReadProgressDeleted = nil
    sseService.onReadProgressSeriesChanged = nil
    sseService.onReadProgressSeriesDeleted = nil
  }

  private func tryReconnect() async {
    isCheckingConnection = true
    let serverReachable = await authViewModel.loadCurrentUser()
    isOffline = !serverReachable
    isCheckingConnection = false

    if serverReachable {
      sseService.connect()
      ErrorManager.shared.notify(message: String(localized: "settings.connection_restored"))
      refreshDashboard(reason: "Reconnected")
    }
  }
}
