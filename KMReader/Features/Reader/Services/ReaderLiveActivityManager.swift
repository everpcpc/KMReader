//
// ReaderLiveActivityManager.swift
//

import Foundation

#if os(iOS)
  import ActivityKit

  @MainActor
  final class ReaderLiveActivityManager {
    private struct SessionSnapshot {
      var book: Book
      var incognito: Bool
      var readingProgress: Double
    }

    static let shared = ReaderLiveActivityManager()

    private let logger = AppLogger(.reader)
    private var currentActivity: Activity<ReaderActivityAttributes>?
    private var currentSnapshot: SessionSnapshot?
    private var lastDeliveredState: ReaderActivityAttributes.ContentState?
    private var preferenceObserverTask: Task<Void, Never>?

    private init() {
      preferenceObserverTask = Task { [weak self] in
        guard let self else { return }
        self.syncActivity()
        for await _ in NotificationCenter.default.notifications(named: UserDefaults.didChangeNotification) {
          self.syncActivity()
        }
      }
    }

    func readerDidOpen(book: Book, incognito: Bool) {
      currentSnapshot = SessionSnapshot(
        book: book,
        incognito: incognito,
        readingProgress: initialProgress(for: book, incognito: incognito)
      )
      syncActivity()
    }

    func readerDidUpdateBook(_ book: Book, incognito: Bool) {
      let updatedProgress: Double
      if currentSnapshot?.book.id == book.id {
        updatedProgress = currentSnapshot?.readingProgress ?? initialProgress(for: book, incognito: incognito)
      } else {
        updatedProgress = initialProgress(for: book, incognito: incognito)
      }

      currentSnapshot = SessionSnapshot(
        book: book,
        incognito: incognito,
        readingProgress: updatedProgress
      )
      syncActivity()
    }

    func updateReadingProgress(_ progress: Double) {
      guard var snapshot = currentSnapshot else { return }
      guard !snapshot.incognito else { return }

      let normalizedProgress = Self.normalizedProgress(progress)
      let previousPercent = Self.displayPercent(for: snapshot.readingProgress)
      let newPercent = Self.displayPercent(for: normalizedProgress)
      guard newPercent != previousPercent else { return }

      snapshot.readingProgress = normalizedProgress
      currentSnapshot = snapshot
      syncActivity()
    }

    func readerDidClose() {
      currentSnapshot = nil
      endCurrentActivity()
    }

    private func endCurrentActivity() {
      let activity = resolveActivity()
      currentActivity = nil
      lastDeliveredState = nil
      guard let activity else { return }
      let activityID = activity.id
      Task {
        await Self.endActivity(id: activityID)
      }
    }

    private func syncActivity() {
      guard AppConfig.enableReaderLiveActivity else {
        endCurrentActivity()
        return
      }

      guard let snapshot = currentSnapshot else {
        endCurrentActivity()
        return
      }

      guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        logger.info("Reader Live Activities are disabled for this app.")
        return
      }

      let state = makeState(sessionState: .reading, snapshot: snapshot)

      if let activity = resolveActivity() {
        guard lastDeliveredState != state else { return }
        update(activity: activity, with: state)
        return
      }

      let attributes = ReaderActivityAttributes(bookId: snapshot.book.id)

      do {
        currentActivity = try Activity.request(
          attributes: attributes,
          content: .init(state: state, staleDate: nil),
          pushType: nil
        )
        lastDeliveredState = state
        logger.info("✅ Reader Live Activity started.")
      } catch {
        logger.error("❌ Failed to start reader Live Activity: \(error)")
      }
    }

    private func makeState(
      sessionState: ReaderActivityAttributes.SessionState,
      snapshot: SessionSnapshot
    ) -> ReaderActivityAttributes.ContentState {
      ReaderActivityAttributes.ContentState(
        sessionState: sessionState,
        readerKind: resolveReaderKind(for: snapshot.book),
        seriesTitle: snapshot.book.oneshot ? nil : snapshot.book.seriesTitle,
        chapterTitle: resolveChapterTitle(for: snapshot.book),
        isIncognito: snapshot.incognito,
        readingProgress: snapshot.incognito ? 0 : snapshot.readingProgress
      )
    }

    private func resolveChapterTitle(for book: Book?) -> String {
      guard let book else {
        return "No active reader"
      }

      if book.metadata.title.isEmpty {
        return book.name
      }

      if book.oneshot {
        return book.metadata.title
      }

      return "#\(book.metadata.number) - \(book.metadata.title)"
    }

    private func resolveReaderKind(for book: Book?) -> ReaderActivityAttributes.ReaderKind {
      guard let book else {
        return .divina
      }

      let mediaProfile = book.media.mediaProfileValue ?? .unknown
      switch mediaProfile {
      case .epub:
        return (book.media.epubDivinaCompatible ?? false) ? .divina : .epub
      case .pdf:
        return AppConfig.useNativePdfReader ? .pdf : .divina
      case .divina, .unknown:
        return .divina
      }
    }

    private func update(
      activity: Activity<ReaderActivityAttributes>,
      with state: ReaderActivityAttributes.ContentState
    ) {
      lastDeliveredState = state
      let activityID = activity.id
      Task {
        await Self.updateActivity(id: activityID, state: state)
      }
    }

    private static nonisolated func updateActivity(
      id: String,
      state: ReaderActivityAttributes.ContentState
    ) async {
      guard let activity = Activity<ReaderActivityAttributes>.activities.first(where: { $0.id == id })
      else { return }
      await activity.update(.init(state: state, staleDate: nil))
    }

    private static nonisolated func endActivity(id: String) async {
      guard let activity = Activity<ReaderActivityAttributes>.activities.first(where: { $0.id == id })
      else { return }
      await activity.end(nil, dismissalPolicy: .immediate)
    }

    private func resolveActivity() -> Activity<ReaderActivityAttributes>? {
      if let currentActivity {
        return currentActivity
      }
      if let existing = Activity<ReaderActivityAttributes>.activities.first {
        currentActivity = existing
        return existing
      }
      return nil
    }

    private func initialProgress(for book: Book, incognito: Bool) -> Double {
      guard !incognito else { return 0 }
      if book.isCompleted {
        return 1
      }
      guard book.media.pagesCount > 0 else { return 0 }
      let page = max(0, book.readProgress?.page ?? 0)
      return Self.normalizedPageProgress(currentPage: page, totalPages: book.media.pagesCount)
    }

    static nonisolated func normalizedProgress(_ progress: Double) -> Double {
      min(max(progress, 0), 1)
    }

    static nonisolated func normalizedPageProgress(currentPage: Int, totalPages: Int) -> Double {
      guard totalPages > 0 else { return 0 }
      return normalizedProgress(Double(max(currentPage, 0)) / Double(totalPages))
    }

    private static nonisolated func displayPercent(for progress: Double) -> Int {
      Int((normalizedProgress(progress) * 100).rounded())
    }
  }
#endif
