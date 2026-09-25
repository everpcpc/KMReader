//
// ReadListReadingService.swift
//
//

import Foundation

/// Owns the read lists the user is reading through, so a read list continues
/// across series the way a series continues across its books: the reader
/// follows read list order from any entry point, and the Read Lists in Progress
/// dashboard section shows each list's next book.
///
/// Opt-in (`AppConfig.readListContinuationEnabled`): while off, nothing is
/// recorded, synced, resolved, or shown, and the snapshot stays empty.
///
/// State lives in `read_list_reading_states` and syncs through Komga's per-user
/// client settings, one key per read list, so it follows the user across
/// devices (requires Komga 1.20.0+, the app's minimum server version).
///
/// What the read lists surface is published as `snapshot`, re-derived after
/// every reading state write and whenever local book progress or read list
/// membership changes. Views observe it rather than being told to reload.
@MainActor
@Observable
final class ReadListReadingService {
  static let shared = ReadListReadingService()

  /// Namespace for this app's keys in Komga's per-user client settings.
  nonisolated static let settingKeyPrefix = "kmreader.readlist."

  private(set) var snapshot: ReadListReadingSnapshot = .empty
  private(set) var activeReadListIds: Set<String> = []

  @ObservationIgnored private var snapshotInstanceId = ""
  @ObservationIgnored private var refreshTask: Task<Void, Never>?
  @ObservationIgnored private var isRefreshRequested = false
  @ObservationIgnored private var isSyncing = false
  @ObservationIgnored private var contentObserverTasks: [Task<Void, Never>] = []
  @ObservationIgnored private let logger = AppLogger(.sync)

  private init() {
    observeContentChanges()
  }

  private var isEnabled: Bool {
    AppConfig.readListContinuationEnabled
  }

  /// The read lists being read on the current server, most recently read first.
  var continuations: [ReadListContinuation] {
    currentSnapshot.continuations
  }

  func isReading(readListId: String) -> Bool {
    isEnabled && activeReadListIds.contains(readListId)
  }

  /// The read list a book continues in when opened without one, if the user is
  /// reading through a read list that contains it.
  func ownerContext(forBookId bookId: String) -> ReaderReadListContext? {
    guard isEnabled else { return nil }
    let snapshot = currentSnapshot
    guard let readListId = snapshot.ownerReadListIdByBookId[bookId],
      let continuation = snapshot.continuation(forReadListId: readListId)
    else { return nil }
    return ReaderReadListContext(id: readListId, name: continuation.readListName)
  }

  func recordReading(readListId: String, bookId: String, instanceId: String) {
    guard isEnabled else { return }
    Task {
      guard let database = await DatabaseOperator.databaseIfConfigured() else { return }
      let recorded = await database.recordReadListReading(
        readListId: readListId,
        bookId: bookId,
        instanceId: instanceId,
        at: Date()
      )
      guard recorded else { return }
      await refreshSnapshot()
      await reconcile(instanceId: instanceId, database: database)
    }
  }

  /// Stops continuing a read list, from any of the places that offer it.
  func stopReading(readListId: String, instanceId: String) {
    guard isEnabled else { return }
    Task {
      guard let database = await DatabaseOperator.databaseIfConfigured() else { return }
      await database.stopReadListReading(readListId: readListId, instanceId: instanceId, at: Date())
      await refreshSnapshot()
      ErrorManager.shared.notify(message: String(localized: "notification.readList.stoppedReading"))
      await reconcile(instanceId: instanceId, database: database)
    }
  }

  func sync(instanceId: String) async {
    guard isEnabled, !instanceId.isEmpty, !isSyncing else { return }
    isSyncing = true
    defer { isSyncing = false }
    guard let database = await DatabaseOperator.databaseIfConfigured() else { return }
    await reconcile(instanceId: instanceId, database: database)
  }

  /// Loads the local state when the setting is turned on, then syncs it;
  /// clears what was shown when it is turned off.
  func settingDidChange() {
    Task {
      await refreshSnapshot()
      await sync(instanceId: AppConfig.current.instanceId)
    }
  }

  /// Re-derives the snapshot from the local database and returns it once every
  /// write that completed before this call is reflected.
  @discardableResult
  func refreshSnapshot() async -> ReadListReadingSnapshot {
    requestRefresh()
    await refreshTask?.value
    return currentSnapshot
  }

  /// The published snapshot, if it belongs to the current server.
  private var currentSnapshot: ReadListReadingSnapshot {
    snapshotInstanceId == AppConfig.current.instanceId ? snapshot : .empty
  }

  /// Refreshes run one at a time, and one requested while another is reading
  /// runs again afterwards, so an older read never publishes over a newer one
  /// and bursts of requests coalesce.
  private func requestRefresh() {
    isRefreshRequested = true
    guard refreshTask == nil else { return }
    refreshTask = Task {
      while isRefreshRequested {
        isRefreshRequested = false
        await loadSnapshot()
      }
      refreshTask = nil
    }
  }

  private func loadSnapshot() async {
    let instanceId = AppConfig.current.instanceId
    guard isEnabled else {
      publish((.empty, []), instanceId: instanceId)
      return
    }
    guard let database = await DatabaseOperator.databaseIfConfigured() else { return }
    let loaded = await database.fetchReadListReadingSnapshot(instanceId: instanceId)
    // A server switch while this was in flight must not publish the previous
    // server's read lists.
    guard instanceId == AppConfig.current.instanceId else { return }
    publish(loaded, instanceId: instanceId)
  }

  private func publish(
    _ loaded: (snapshot: ReadListReadingSnapshot, activeReadListIds: Set<String>),
    instanceId: String
  ) {
    if loaded.snapshot != snapshot {
      let summary = loaded.snapshot.continuations.map { "\($0.readListName) → \($0.bookId)" }
      logger.debug("📚 Read list continuations: \(summary)")
      snapshot = loaded.snapshot
    }
    if loaded.activeReadListIds != activeReadListIds {
      activeReadListIds = loaded.activeReadListIds
    }
    snapshotInstanceId = instanceId
  }

  /// Continuations are derived from book progress, download status, and read
  /// list membership, so local changes to any of them re-derive them, wherever
  /// they came from (the reader, a sync, another device through SSE).
  private func observeContentChanges() {
    contentObserverTasks.append(
      Task { @MainActor [weak self] in
        for await _ in NotificationCenter.default.notifications(named: .bookProjectionDidChange) {
          guard let self, !activeReadListIds.isEmpty else { continue }
          requestRefresh()
        }
      }
    )
    contentObserverTasks.append(
      Task { @MainActor [weak self] in
        for await _ in NotificationCenter.default.notifications(named: .readListProjectionDidChange) {
          guard let self, !activeReadListIds.isEmpty else { continue }
          requestRefresh()
        }
      }
    )
  }

  /// Pulls the server's copy first and keeps, per read list, whichever change
  /// happened last on any device, a read or a stop; then pushes the local
  /// changes that won. A pull never undoes a newer local change, and an
  /// offline stop never deletes a read another device made after it.
  private func reconcile(instanceId: String, database: DatabaseOperator) async {
    if !AppConfig.isOffline {
      do {
        let settings = try await ClientSettingsService.getUserSettings()
        // A server switch while the pull was in flight must not apply or push
        // the previous server's read lists.
        if instanceId == AppConfig.current.instanceId {
          await database.applyRemoteReadListReadingStates(
            Self.decodeRemoteStates(settings),
            instanceId: instanceId
          )
          await uploadPendingChanges(instanceId: instanceId, database: database)
        }
      } catch {
        logger.debug("📚 Skipped read list reading state sync: \(error)")
      }
    }
    await refreshSnapshot()
  }

  private func uploadPendingChanges(instanceId: String, database: DatabaseOperator) async {
    // Pushes go to the current server; a switch mid-flight must not write the
    // previous server's state to it.
    guard instanceId == AppConfig.current.instanceId else { return }
    let pending = await database.fetchReadListReadingStates(instanceId: instanceId).filter(\.needsUpload)
    let updated = pending.filter { !$0.isStopped }
    let stopped = pending.filter(\.isStopped)

    var settings: [String: String] = [:]
    for state in updated {
      guard let key = Self.settingKey(forReadListId: state.readListId),
        let value = Self.encodeValue(state)
      else { continue }
      settings[key] = value
    }
    if !settings.isEmpty {
      do {
        try await ClientSettingsService.saveUserSettings(settings)
        await database.markReadListReadingUploaded(updated)
      } catch {
        logger.debug("📚 Deferred read list reading state upload: \(error)")
      }
    }

    let stoppedKeys = stopped.compactMap { Self.settingKey(forReadListId: $0.readListId) }
    if !stoppedKeys.isEmpty {
      do {
        try await ClientSettingsService.deleteUserSettings(keys: stoppedKeys)
        await database.deleteStoppedReadListReadingStates(
          readListIds: stopped.map(\.readListId),
          instanceId: instanceId
        )
      } catch {
        logger.debug("📚 Deferred read list stop upload: \(error)")
      }
    }
  }

  /// Komga requires each key segment to be lowercase alphanumeric. Read list
  /// ids are case-insensitive base32, so lowercasing them is lossless; the
  /// original id also travels in the value.
  nonisolated static func settingKey(forReadListId readListId: String) -> String? {
    let segment = readListId.lowercased()
    guard !segment.isEmpty,
      segment.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) })
    else { return nil }
    return settingKeyPrefix + segment
  }

  nonisolated private static func encodeValue(_ state: ReadListReadingState) -> String? {
    let payload: [String: Any] = [
      "readListId": state.readListId,
      "bookId": state.lastReadBookId,
      "readAt": state.lastReadAt.timeIntervalSince1970,
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  nonisolated private static func decodeRemoteStates(
    _ settings: [String: String]
  ) -> [String: (bookId: String, readAt: Date)] {
    var states: [String: (bookId: String, readAt: Date)] = [:]
    for (key, value) in settings where key.hasPrefix(settingKeyPrefix) {
      guard let data = value.data(using: .utf8),
        let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let readListId = payload["readListId"] as? String,
        let bookId = payload["bookId"] as? String,
        let readAt = payload["readAt"] as? Double,
        settingKey(forReadListId: readListId) == key
      else { continue }
      states[readListId] = (bookId, Date(timeIntervalSince1970: readAt))
    }
    return states
  }
}
