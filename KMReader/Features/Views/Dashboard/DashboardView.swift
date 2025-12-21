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
  @State private var bookViewModel = BookViewModel()
  @State private var seriesViewModel = SeriesViewModel()
  @State private var refreshTrigger = UUID()
  @State private var isRefreshDisabled = false
  @State private var pendingRefreshTask: Task<Void, Never>?
  @State private var showLibraryPicker = false
  @State private var shouldRefreshAfterReading = false

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @AppStorage("enableSSEAutoRefresh") private var enableSSEAutoRefresh: Bool = true
  @AppStorage("enableSSE") private var enableSSE: Bool = true

  @Environment(ReaderPresentationManager.self) private var readerPresentation

  private let sseService = SSEService.shared
  private let debounceInterval: TimeInterval = 5.0  // 5 seconds debounce - wait for events to settle
  private let logger = AppLogger(.dashboard)

  private func performRefresh(reason: String) {
    logger.debug("Dashboard refresh start: \(reason)")

    // Update refresh trigger to cause all sections to reload
    refreshTrigger = UUID()
    isRefreshDisabled = true
    Task {
      try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
      isRefreshDisabled = false
    }
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
    performRefresh(reason: reason)
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
          performRefresh(reason: "Auto after debounce: \(reason)")
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
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          HStack {
            if enableSSE {
              #if os(tvOS)
                Button {
                  refreshDashboard(reason: "Manual tvOS button")
                } label: {
                  Label("Refresh", systemImage: "arrow.clockwise.circle")
                }
                .disabled(isRefreshDisabled)
              #endif
              ServerUpdateStatusView()
            }
            Spacer()
          }.padding()

          ForEach(dashboard.sections, id: \.id) { section in
            switch section {
            case .keepReading, .onDeck, .recentlyReadBooks, .recentlyReleasedBooks,
              .recentlyAddedBooks:
              DashboardBooksSection(
                section: section,
                bookViewModel: bookViewModel,
                refreshTrigger: refreshTrigger,
                onBookUpdated: {
                  refreshDashboard(reason: "Book action completed")
                }
              )
              .transition(.move(edge: .top).combined(with: .opacity))

            case .recentlyUpdatedSeries, .recentlyAddedSeries:
              DashboardSeriesSection(
                section: section,
                seriesViewModel: seriesViewModel,
                refreshTrigger: refreshTrigger,
                onSeriesUpdated: {
                  refreshDashboard(reason: "Series action completed")
                }
              )
              .transition(.move(edge: .top).combined(with: .opacity))
            }
          }
        }
        .padding(.vertical)
      }
      .handleNavigation()
      .inlineNavigationBarTitle(String(localized: "title.dashboard"))
      .animation(.default, value: dashboard)
      .onChange(of: currentInstanceId) { _, _ in
        // Reset server last update time when switching servers
        // Bypass auto-refresh setting for configuration changes
        refreshDashboard(reason: "Instance changed")
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
          shouldRefreshAfterReading = false
          refreshDashboard(reason: "Deferred after reader closed")
        } else if !enableSSE {
          // Without SSE events we refresh when exiting the reader
          refreshDashboard(reason: "Reader closed without SSE")
        }
      }
      #if !os(tvOS)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button {
              showLibraryPicker = true
            } label: {
              Image(systemName: "books.vertical")
            }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button {
              refreshDashboard(reason: "Manual toolbar button")
            } label: {
              Image(systemName: "arrow.clockwise.circle")
            }
            .disabled(isRefreshDisabled)
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
}
