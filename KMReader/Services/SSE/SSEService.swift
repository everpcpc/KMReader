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

    guard !AppConfig.isOffline else {
      logger.info("SSE connection skipped: app is offline")
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
      if AppConfig.isLoggedIn && AppConfig.enableSSE && !AppConfig.isOffline && !Task.isCancelled {
        Task {
          try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
          if AppConfig.isLoggedIn && !isConnected && AppConfig.enableSSE && !AppConfig.isOffline {
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
        if AppConfig.isLoggedIn && AppConfig.enableSSE && !AppConfig.isOffline {
          Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
            if AppConfig.isLoggedIn && !isConnected && AppConfig.enableSSE && !AppConfig.isOffline {
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

    switch type {
    case "LibraryAdded":
      dispatchToMain(handler: onLibraryAdded, data: data, as: LibrarySSEDto.self)
    case "LibraryChanged":
      dispatchToMain(handler: onLibraryChanged, data: data, as: LibrarySSEDto.self)
    case "LibraryDeleted":
      dispatchToMain(handler: onLibraryDeleted, data: data, as: LibrarySSEDto.self)

    case "SeriesAdded":
      dispatchToMain(handler: onSeriesAdded, data: data, as: SeriesSSEDto.self)
    case "SeriesChanged":
      dispatchToMain(handler: onSeriesChanged, data: data, as: SeriesSSEDto.self)
    case "SeriesDeleted":
      dispatchToMain(handler: onSeriesDeleted, data: data, as: SeriesSSEDto.self)

    case "BookAdded":
      dispatchToMain(handler: onBookAdded, data: data, as: BookSSEDto.self)
    case "BookChanged":
      dispatchToMain(handler: onBookChanged, data: data, as: BookSSEDto.self)
    case "BookDeleted":
      dispatchToMain(handler: onBookDeleted, data: data, as: BookSSEDto.self)
    case "BookImported":
      dispatchToMain(handler: onBookImported, data: data, as: BookImportSSEDto.self)

    case "CollectionAdded":
      dispatchToMain(handler: onCollectionAdded, data: data, as: CollectionSSEDto.self)
    case "CollectionChanged":
      dispatchToMain(handler: onCollectionChanged, data: data, as: CollectionSSEDto.self)
    case "CollectionDeleted":
      dispatchToMain(handler: onCollectionDeleted, data: data, as: CollectionSSEDto.self)

    case "ReadListAdded":
      dispatchToMain(handler: onReadListAdded, data: data, as: ReadListSSEDto.self)
    case "ReadListChanged":
      dispatchToMain(handler: onReadListChanged, data: data, as: ReadListSSEDto.self)
    case "ReadListDeleted":
      dispatchToMain(handler: onReadListDeleted, data: data, as: ReadListSSEDto.self)

    case "ReadProgressChanged":
      dispatchToMain(handler: onReadProgressChanged, data: data, as: ReadProgressSSEDto.self)
    case "ReadProgressDeleted":
      dispatchToMain(handler: onReadProgressDeleted, data: data, as: ReadProgressSSEDto.self)
    case "ReadProgressSeriesChanged":
      dispatchToMain(
        handler: onReadProgressSeriesChanged, data: data, as: ReadProgressSeriesSSEDto.self)
    case "ReadProgressSeriesDeleted":
      dispatchToMain(
        handler: onReadProgressSeriesDeleted, data: data, as: ReadProgressSeriesSSEDto.self)

    case "ThumbnailBookAdded":
      dispatchToMain(handler: onThumbnailBookAdded, data: data, as: ThumbnailBookSSEDto.self)
    case "ThumbnailBookDeleted":
      dispatchToMain(handler: onThumbnailBookDeleted, data: data, as: ThumbnailBookSSEDto.self)
    case "ThumbnailSeriesAdded":
      dispatchToMain(handler: onThumbnailSeriesAdded, data: data, as: ThumbnailSeriesSSEDto.self)
    case "ThumbnailSeriesDeleted":
      dispatchToMain(handler: onThumbnailSeriesDeleted, data: data, as: ThumbnailSeriesSSEDto.self)
    case "ThumbnailReadListAdded":
      dispatchToMain(
        handler: onThumbnailReadListAdded, data: data, as: ThumbnailReadListSSEDto.self)
    case "ThumbnailReadListDeleted":
      dispatchToMain(
        handler: onThumbnailReadListDeleted, data: data, as: ThumbnailReadListSSEDto.self)
    case "ThumbnailSeriesCollectionAdded":
      dispatchToMain(
        handler: onThumbnailCollectionAdded, data: data, as: ThumbnailCollectionSSEDto.self)
    case "ThumbnailSeriesCollectionDeleted":
      dispatchToMain(
        handler: onThumbnailCollectionDeleted, data: data, as: ThumbnailCollectionSSEDto.self)

    case "TaskQueueStatus":
      handleTaskQueueStatus(data: data)
    case "SessionExpired":
      dispatchToMain(handler: onSessionExpired, data: data, as: SessionExpiredSSEDto.self)

    default:
      logger.debug("Unknown SSE event type: \(type)")
    }
  }

  private func handleTaskQueueStatus(data: String) {
    guard let jsonData = data.data(using: .utf8),
      let dto = try? JSONDecoder().decode(TaskQueueSSEDto.self, from: jsonData)
    else { return }

    let previousStatus = AppConfig.taskQueueStatus
    guard previousStatus != dto else { return }

    AppConfig.taskQueueStatus = dto
    dispatchToMain(handler: onTaskQueueStatus, dto: dto)

    if previousStatus.count > 0 && dto.count == 0 && AppConfig.enableSSENotify {
      Task { @MainActor in
        ErrorManager.shared.notify(
          message: String(localized: "notification.sse.tasksFinished"))
      }
    }
  }

  private func dispatchToMain<T: Decodable>(handler: ((T) -> Void)?, data: String, as type: T.Type)
  {
    guard let handler else { return }
    guard let jsonData = data.data(using: .utf8),
      let dto = try? JSONDecoder().decode(type, from: jsonData)
    else { return }
    Task { @MainActor in
      handler(dto)
    }
  }

  private func dispatchToMain<T>(handler: ((T) -> Void)?, dto: T) {
    guard let handler else { return }
    Task { @MainActor in
      handler(dto)
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
