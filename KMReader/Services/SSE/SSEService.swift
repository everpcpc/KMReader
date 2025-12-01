//
//  SSEService.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog

@MainActor
class SSEService {
  static let shared = SSEService()

  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "KMReader", category: "SSE")

  private var streamTask: Task<Void, Never>?
  private var isConnected = false

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
    streamTask = Task {
      await handleSSEStream(url: url)
    }
    isConnected = true
  }

  func disconnect() {
    guard isConnected else { return }

    logger.info("🔌 Disconnecting SSE")
    streamTask?.cancel()
    streamTask = nil
    isConnected = false

    // Clear task queue status when disconnecting
    AppConfig.taskQueueStatus = TaskQueueSSEDto()

    // Notify user that SSE disconnected
    ErrorManager.shared.notify(message: "Real-time updates disconnected")
  }

  private func handleSSEStream(url: URL) async {
    var request = URLRequest(url: url)
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

    if !AppConfig.authToken.isEmpty {
      request.setValue("Basic \(AppConfig.authToken)", forHTTPHeaderField: "Authorization")
    }

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
        isConnected = false
        return
      }

      logger.info("✅ SSE connected")

      // Notify user that SSE connected successfully
      ErrorManager.shared.notify(message: "Real-time updates connected")

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
              handleSSEEvent(type: eventType, data: data)
            }
            currentEventType = nil
            currentData = nil
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
          // Ignore id: and retry: lines for now
        } else {
          lineBuffer.append(character)
        }
      }
    } catch {
      if !Task.isCancelled {
        logger.error("SSE stream error: \(error.localizedDescription)")
        isConnected = false

        // Attempt to reconnect after a delay
        Task {
          try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
          if AppConfig.isLoggedIn && !isConnected {
            connect()
          }
        }
      }
    }
  }

  private func handleSSEEvent(type: String, data: String) {
    guard let jsonData = data.data(using: .utf8) else {
      logger.warning("Invalid SSE data: \(data)")
      return
    }

    let decoder = JSONDecoder()

    switch type {
    case "LibraryAdded":
      if let dto = try? decoder.decode(LibrarySSEDto.self, from: jsonData) {
        onLibraryAdded?(dto)
      }
    case "LibraryChanged":
      if let dto = try? decoder.decode(LibrarySSEDto.self, from: jsonData) {
        onLibraryChanged?(dto)
      }
    case "LibraryDeleted":
      if let dto = try? decoder.decode(LibrarySSEDto.self, from: jsonData) {
        onLibraryDeleted?(dto)
      }

    case "SeriesAdded":
      if let dto = try? decoder.decode(SeriesSSEDto.self, from: jsonData) {
        onSeriesAdded?(dto)
      }
    case "SeriesChanged":
      if let dto = try? decoder.decode(SeriesSSEDto.self, from: jsonData) {
        onSeriesChanged?(dto)
      }
    case "SeriesDeleted":
      if let dto = try? decoder.decode(SeriesSSEDto.self, from: jsonData) {
        onSeriesDeleted?(dto)
      }

    case "BookAdded":
      if let dto = try? decoder.decode(BookSSEDto.self, from: jsonData) {
        onBookAdded?(dto)
      }
    case "BookChanged":
      if let dto = try? decoder.decode(BookSSEDto.self, from: jsonData) {
        onBookChanged?(dto)
      }
    case "BookDeleted":
      if let dto = try? decoder.decode(BookSSEDto.self, from: jsonData) {
        onBookDeleted?(dto)
      }
    case "BookImported":
      if let dto = try? decoder.decode(BookImportSSEDto.self, from: jsonData) {
        onBookImported?(dto)
      }

    case "CollectionAdded":
      if let dto = try? decoder.decode(CollectionSSEDto.self, from: jsonData) {
        onCollectionAdded?(dto)
      }
    case "CollectionChanged":
      if let dto = try? decoder.decode(CollectionSSEDto.self, from: jsonData) {
        onCollectionChanged?(dto)
      }
    case "CollectionDeleted":
      if let dto = try? decoder.decode(CollectionSSEDto.self, from: jsonData) {
        onCollectionDeleted?(dto)
      }

    case "ReadListAdded":
      if let dto = try? decoder.decode(ReadListSSEDto.self, from: jsonData) {
        onReadListAdded?(dto)
      }
    case "ReadListChanged":
      if let dto = try? decoder.decode(ReadListSSEDto.self, from: jsonData) {
        onReadListChanged?(dto)
      }
    case "ReadListDeleted":
      if let dto = try? decoder.decode(ReadListSSEDto.self, from: jsonData) {
        onReadListDeleted?(dto)
      }

    case "ReadProgressChanged":
      if let dto = try? decoder.decode(ReadProgressSSEDto.self, from: jsonData) {
        onReadProgressChanged?(dto)
      }
    case "ReadProgressDeleted":
      if let dto = try? decoder.decode(ReadProgressSSEDto.self, from: jsonData) {
        onReadProgressDeleted?(dto)
      }
    case "ReadProgressSeriesChanged":
      if let dto = try? decoder.decode(ReadProgressSeriesSSEDto.self, from: jsonData) {
        onReadProgressSeriesChanged?(dto)
      }
    case "ReadProgressSeriesDeleted":
      if let dto = try? decoder.decode(ReadProgressSeriesSSEDto.self, from: jsonData) {
        onReadProgressSeriesDeleted?(dto)
      }

    case "ThumbnailBookAdded":
      if let dto = try? decoder.decode(ThumbnailBookSSEDto.self, from: jsonData) {
        onThumbnailBookAdded?(dto)
      }
    case "ThumbnailBookDeleted":
      if let dto = try? decoder.decode(ThumbnailBookSSEDto.self, from: jsonData) {
        onThumbnailBookDeleted?(dto)
      }
    case "ThumbnailSeriesAdded":
      if let dto = try? decoder.decode(ThumbnailSeriesSSEDto.self, from: jsonData) {
        onThumbnailSeriesAdded?(dto)
      }
    case "ThumbnailSeriesDeleted":
      if let dto = try? decoder.decode(ThumbnailSeriesSSEDto.self, from: jsonData) {
        onThumbnailSeriesDeleted?(dto)
      }
    case "ThumbnailReadListAdded":
      if let dto = try? decoder.decode(ThumbnailReadListSSEDto.self, from: jsonData) {
        onThumbnailReadListAdded?(dto)
      }
    case "ThumbnailReadListDeleted":
      if let dto = try? decoder.decode(ThumbnailReadListSSEDto.self, from: jsonData) {
        onThumbnailReadListDeleted?(dto)
      }
    case "ThumbnailSeriesCollectionAdded":
      if let dto = try? decoder.decode(ThumbnailCollectionSSEDto.self, from: jsonData) {
        onThumbnailCollectionAdded?(dto)
      }
    case "ThumbnailSeriesCollectionDeleted":
      if let dto = try? decoder.decode(ThumbnailCollectionSSEDto.self, from: jsonData) {
        onThumbnailCollectionDeleted?(dto)
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
          onTaskQueueStatus?(dto)

          // Notify if tasks completed (went from > 0 to 0)
          if previousStatus.count > 0 && dto.count == 0 {
            ErrorManager.shared.notify(message: "All server tasks finished")
          }
        }
      }
    case "SessionExpired":
      if let dto = try? decoder.decode(SessionExpiredSSEDto.self, from: jsonData) {
        onSessionExpired?(dto)
      }

    default:
      logger.debug("Unknown SSE event type: \(type)")
    }
  }
}
