//
// ReaderLiveActivityManager.swift
//

import Foundation

#if os(iOS)
  import ActivityKit

  @MainActor
  final class ReaderLiveActivityManager {
    static let shared = ReaderLiveActivityManager()

    private let logger = AppLogger(.reader)
    private var currentActivity: Activity<ReaderActivityAttributes>?
    private var pendingEndTask: Task<Void, Never>?

    private init() {}

    func readerDidOpen(book: Book) {
      pendingEndTask?.cancel()
      pendingEndTask = nil

      let state = makeState(sessionState: .reading, book: book)

      if let activity = resolveActivity() {
        update(activity: activity, with: state)
        return
      }

      guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        logger.info("Reader Live Activities are disabled for this app.")
        return
      }

      let attributes = ReaderActivityAttributes(bookId: book.id)

      do {
        currentActivity = try Activity.request(
          attributes: attributes,
          content: .init(state: state, staleDate: nil),
          pushType: nil
        )
        logger.info("✅ Reader Live Activity started.")
      } catch {
        logger.error("❌ Failed to start reader Live Activity: \(error)")
      }
    }

    func readerDidClose(book: Book?) {
      guard let activity = resolveActivity() else { return }

      let state = makeState(sessionState: .closed, book: book)
      update(activity: activity, with: state)

      pendingEndTask?.cancel()
      pendingEndTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(12))
        guard !Task.isCancelled else { return }
        self?.endCurrentActivity()
      }
    }

    private func endCurrentActivity() {
      guard let activity = resolveActivity() else { return }
      Task {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
      currentActivity = nil
    }

    private func makeState(
      sessionState: ReaderActivityAttributes.SessionState,
      book: Book?
    ) -> ReaderActivityAttributes.ContentState {
      ReaderActivityAttributes.ContentState(
        sessionState: sessionState,
        readerKind: resolveReaderKind(for: book),
        seriesTitle: book?.seriesTitle ?? "",
        chapterTitle: resolveChapterTitle(for: book)
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
      Task {
        await activity.update(.init(state: state, staleDate: nil))
      }
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
  }
#endif
