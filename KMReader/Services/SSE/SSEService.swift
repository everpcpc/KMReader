//
//  SSEService.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog

private actor SSEStreamActor {
  private var task: Task<Void, Never>?

  func start(service: SSEService, url: URL) async {
    task?.cancel()
    task = Task.detached(priority: .utility) { [weak service] in
      guard let service else { return }
      await service.handleSSEStream(url: url)
    }
  }

  func cancel() async {
    task?.cancel()
    task = nil
  }

  func isRunning() async -> Bool {
    task != nil
  }
}

final class SSEService {
  static let shared = SSEService()

  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "KMReader", category: "SSE")

  private var isConnected = false
  private let streamActor = SSEStreamActor()
  private var lastServerUpdateAt = Date(timeIntervalSince1970: 0)
  private let serverUpdateThrottle: TimeInterval = 1.0

  @MainActor
  var connected: Bool {
    isConnected
  }

  // Event handlers
  var onLibraryAdded: ((LibrarySSEDto) -> Void)?
  var onLibraryChanged: ((LibrarySSEDto) -> Void)?
  var onLibraryDeleted: ((LibrarySSEDto) -> Void)?

  var onSeriesAdded: ((SeriesSSEDto) -> Void)?
  var onSeriesChanged: ((SeriesSSEDto) -> Void)?
  var onSeriesDeleted: ((SeriesSSEDto) -> Void)?

  var onBookAdded: ((BookSSEDto) -> Void)?
  var onBookChanged: ((BookSSEDto) -> Void)?
  var onBookDeleted: ((BookSSEDto) -> Void)?
  var onBookImported: ((BookImportSSEDto) -> Void)?

  var onCollectionAdded: ((CollectionSSEDto) -> Void)?
  var onCollectionChanged: ((CollectionSSEDto) -> Void)?
  var onCollectionDeleted: ((CollectionSSEDto) -> Void)?

  var onReadListAdded: ((ReadListSSEDto) -> Void)?
  var onReadListChanged: ((ReadListSSEDto) -> Void)?
  var onReadListDeleted: ((ReadListSSEDto) -> Void)?

  var onReadProgressChanged: ((ReadProgressSSEDto) -> Void)?
  var onReadProgressDeleted: ((ReadProgressSSEDto) -> Void)?
  var onReadProgressSeriesChanged: ((ReadProgressSeriesSSEDto) -> Void)?
  var onReadProgressSeriesDeleted: ((ReadProgressSeriesSSEDto) -> Void)?

  var onThumbnailBookAdded: ((ThumbnailBookSSEDto) -> Void)?
  var onThumbnailBookDeleted: ((ThumbnailBookSSEDto) -> Void)?
  var onThumbnailSeriesAdded: ((ThumbnailSeriesSSEDto) -> Void)?
  var onThumbnailSeriesDeleted: ((ThumbnailSeriesSSEDto) -> Void)?
  var onThumbnailReadListAdded: ((ThumbnailReadListSSEDto) -> Void)?
  var onThumbnailReadListDeleted: ((ThumbnailReadListSSEDto) -> Void)?
  var onThumbnailCollectionAdded: ((ThumbnailCollectionSSEDto) -> Void)?
  var onThumbnailCollectionDeleted: ((ThumbnailCollectionSSEDto) -> Void)?

  var onTaskQueueStatus: ((TaskQueueSSEDto) -> Void)?
  var onSessionExpired: ((SessionExpiredSSEDto) -> Void)?

  private init() {}

  @MainActor
  func connect() {
    guard !isConnected else {
      logger.info("SSE already connected")
      return
    }

    guard AppConfig.enableSSE else {
      logger.info("SSE is disabled by user preference")
      return
    }

    guard !AppConfig.serverURL.isEmpty, !AppConfig.authToken.isEmpty else {
      logger.warning("Cannot connect SSE: missing server URL or auth token")
      return
    }

    guard let url = URL(string: AppConfig.serverURL + "/sse/v1/events") else {
      logger.error("Invalid SSE URL: \(AppConfig.serverURL)/sse/v1/events")
      return
    }

    logger.info("🔌 Connecting to SSE: \(url.absoluteString)")
    Task {
      await streamActor.start(service: self, url: url)
    }
    isConnected = true
  }

  @MainActor
  func disconnect() {
    guard isConnected else { return }

    logger.info("🔌 Disconnecting SSE")
    Task {
      await streamActor.cancel()
    }
    isConnected = false

    // Clear task queue status when disconnecting
    AppConfig.taskQueueStatus = TaskQueueSSEDto()

    // Notify user that SSE disconnected (if notifications enabled)
    if AppConfig.enableSSENotify {
      ErrorManager.shared.notify(message: String(localized: "notification.sse.disconnected"))
    }
  }

  fileprivate func handleSSEStream(url: URL) async {
    var request = URLRequest(url: url)
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

    let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "KMReader"
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    let device = PlatformHelper.deviceModel
    let osVersion = PlatformHelper.osVersion
    #if os(iOS)
      let platform = "iOS"
    #elseif os(macOS)
      let platform = "macOS"
    #elseif os(tvOS)
      let platform = "tvOS"
    #else
      let platform = "Unknown"
    #endif
    let userAgent =
      "\(appName)/\(appVersion) (\(device); \(platform) \(osVersion); Build \(buildNumber))"
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

    do {
      let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

      guard let httpResponse = response as? HTTPURLResponse,
        (200...299).contains(httpResponse.statusCode)
      else {
        logger.error("SSE connection failed: \(response)")
        await MainActor.run {
          self.isConnected = false
        }
        return
      }

      logger.info("✅ SSE connected")

      // Notify user that SSE connected successfully (if notifications enabled)
      if AppConfig.enableSSENotify {
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.sse.connected"))
        }
      }

      var lineBuffer = ""
      var currentEventType: String?
      var currentData: String?

      for try await byte in asyncBytes {
        if Task.isCancelled {
          break
        }

        let character = Character(UnicodeScalar(byte))

        if character == "\n" {
          // Process complete line
          let line = lineBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
          lineBuffer = ""

          if line.isEmpty {
            // Empty line indicates end of message
            if let eventType = currentEventType, let data = currentData {
              await handleSSEEvent(type: eventType, data: data)
            }
            currentEventType = nil
            currentData = nil
          } else if line.hasPrefix(":") {
            // SSE comment line (heartbeat) - ignore but confirms connection is alive
          } else if line.hasPrefix("event:") {
            currentEventType = String(line.dropFirst(6).trimmingCharacters(in: .whitespaces))
          } else if line.hasPrefix("data:") {
            let data = String(line.dropFirst(5).trimmingCharacters(in: .whitespaces))
            if currentData == nil {
              currentData = data
            } else {
              // Multi-line data
              currentData! += "\n" + data
            }
          }
          // Ignore id: and retry: lines
        } else {
          lineBuffer.append(character)
        }
      }

      // Stream ended - connection closed
      logger.warning("SSE stream ended - connection closed")
      await MainActor.run {
        self.isConnected = false
      }

      // Attempt to reconnect if still logged in
      if AppConfig.isLoggedIn && AppConfig.enableSSE && !Task.isCancelled {
        Task {
          try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
          if AppConfig.isLoggedIn && !isConnected && AppConfig.enableSSE {
            logger.info("Reconnecting SSE after stream ended")
            await MainActor.run {
              self.connect()
            }
          }
        }
      }
    } catch {
      if !Task.isCancelled {
        logger.error("SSE stream error: \(error.localizedDescription)")
        await MainActor.run {
          self.isConnected = false
        }

        // Attempt to reconnect after a delay
        if AppConfig.isLoggedIn && AppConfig.enableSSE {
          Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
            if AppConfig.isLoggedIn && !isConnected && AppConfig.enableSSE {
              logger.info("Reconnecting SSE after error")
              await MainActor.run {
                self.connect()
              }
            }
          }
        }
      }
    }
  }

  private func handleSSEEvent(type: String, data: String) async {
    recordServerUpdate()

    guard let jsonData = data.data(using: .utf8) else {
      logger.warning("Invalid SSE data: \(data)")
      return
    }

    let decoder = JSONDecoder()

    switch type {
    case "LibraryAdded":
      if let dto = try? decoder.decode(LibrarySSEDto.self, from: jsonData) {
        dispatchToMain(handler: onLibraryAdded, value: dto)
      }
    case "LibraryChanged":
      if let dto = try? decoder.decode(LibrarySSEDto.self, from: jsonData) {
        dispatchToMain(handler: onLibraryChanged, value: dto)
      }
    case "LibraryDeleted":
      if let dto = try? decoder.decode(LibrarySSEDto.self, from: jsonData) {
        dispatchToMain(handler: onLibraryDeleted, value: dto)
      }

    case "SeriesAdded":
      if let dto = try? decoder.decode(SeriesSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onSeriesAdded, value: dto)
      }
    case "SeriesChanged":
      if let dto = try? decoder.decode(SeriesSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onSeriesChanged, value: dto)
      }
    case "SeriesDeleted":
      if let dto = try? decoder.decode(SeriesSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onSeriesDeleted, value: dto)
      }

    case "BookAdded":
      if let dto = try? decoder.decode(BookSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onBookAdded, value: dto)
      }
    case "BookChanged":
      if let dto = try? decoder.decode(BookSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onBookChanged, value: dto)
      }
    case "BookDeleted":
      if let dto = try? decoder.decode(BookSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onBookDeleted, value: dto)
      }
    case "BookImported":
      if let dto = try? decoder.decode(BookImportSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onBookImported, value: dto)
      }

    case "CollectionAdded":
      if let dto = try? decoder.decode(CollectionSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onCollectionAdded, value: dto)
      }
    case "CollectionChanged":
      if let dto = try? decoder.decode(CollectionSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onCollectionChanged, value: dto)
      }
    case "CollectionDeleted":
      if let dto = try? decoder.decode(CollectionSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onCollectionDeleted, value: dto)
      }

    case "ReadListAdded":
      if let dto = try? decoder.decode(ReadListSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onReadListAdded, value: dto)
      }
    case "ReadListChanged":
      if let dto = try? decoder.decode(ReadListSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onReadListChanged, value: dto)
      }
    case "ReadListDeleted":
      if let dto = try? decoder.decode(ReadListSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onReadListDeleted, value: dto)
      }

    case "ReadProgressChanged":
      if let dto = try? decoder.decode(ReadProgressSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onReadProgressChanged, value: dto)
      }
    case "ReadProgressDeleted":
      if let dto = try? decoder.decode(ReadProgressSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onReadProgressDeleted, value: dto)
      }
    case "ReadProgressSeriesChanged":
      if let dto = try? decoder.decode(ReadProgressSeriesSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onReadProgressSeriesChanged, value: dto)
      }
    case "ReadProgressSeriesDeleted":
      if let dto = try? decoder.decode(ReadProgressSeriesSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onReadProgressSeriesDeleted, value: dto)
      }

    case "ThumbnailBookAdded":
      if let dto = try? decoder.decode(ThumbnailBookSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onThumbnailBookAdded, value: dto)
      }
    case "ThumbnailBookDeleted":
      if let dto = try? decoder.decode(ThumbnailBookSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onThumbnailBookDeleted, value: dto)
      }
    case "ThumbnailSeriesAdded":
      if let dto = try? decoder.decode(ThumbnailSeriesSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onThumbnailSeriesAdded, value: dto)
      }
    case "ThumbnailSeriesDeleted":
      if let dto = try? decoder.decode(ThumbnailSeriesSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onThumbnailSeriesDeleted, value: dto)
      }
    case "ThumbnailReadListAdded":
      if let dto = try? decoder.decode(ThumbnailReadListSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onThumbnailReadListAdded, value: dto)
      }
    case "ThumbnailReadListDeleted":
      if let dto = try? decoder.decode(ThumbnailReadListSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onThumbnailReadListDeleted, value: dto)
      }
    case "ThumbnailSeriesCollectionAdded":
      if let dto = try? decoder.decode(ThumbnailCollectionSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onThumbnailCollectionAdded, value: dto)
      }
    case "ThumbnailSeriesCollectionDeleted":
      if let dto = try? decoder.decode(ThumbnailCollectionSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onThumbnailCollectionDeleted, value: dto)
      }

    case "TaskQueueStatus":
      if let dto = try? decoder.decode(TaskQueueSSEDto.self, from: jsonData) {
        // Check if status has changed
        let previousStatus = AppConfig.taskQueueStatus

        // Only update if status has changed
        if previousStatus != dto {
          // Store in AppConfig for AppStorage access
          AppConfig.taskQueueStatus = dto

          // Notify the listener
          dispatchToMain(handler: onTaskQueueStatus, value: dto)

          // Notify if tasks completed (went from > 0 to 0) and notifications enabled
          if previousStatus.count > 0 && dto.count == 0 && AppConfig.enableSSENotify {
            await MainActor.run {
              ErrorManager.shared.notify(
                message: String(localized: "notification.sse.tasksFinished"))
            }
          }
        }
      }
    case "SessionExpired":
      if let dto = try? decoder.decode(SessionExpiredSSEDto.self, from: jsonData) {
        dispatchToMain(handler: onSessionExpired, value: dto)
      }

    default:
      logger.debug("Unknown SSE event type: \(type)")
    }
  }

  private func dispatchToMain<T>(handler: ((T) -> Void)?, value: T) {
    guard let handler else { return }
    Task { @MainActor in
      handler(value)
    }
  }

  private func recordServerUpdate() {
    let now = Date()
    if now.timeIntervalSince1970 - lastServerUpdateAt.timeIntervalSince1970 >= serverUpdateThrottle
    {
      lastServerUpdateAt = now
      AppConfig.serverLastUpdate = now
    }
  }
}

extension SSEService: @unchecked Sendable {}
