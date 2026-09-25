//
// DatabaseOperator+ReadListReading.swift
//
//

import Foundation
import GRDB

extension DatabaseOperator {
  func fetchReadListReadingStates(instanceId: String) -> [ReadListReadingState] {
    guard !instanceId.isEmpty else { return [] }
    return
      (try? read { db in
        try ReadListReadingState
          .filter(Column("instance_id") == instanceId)
          .fetchAll(db)
      }) ?? []
  }

  /// Records that `bookId` was opened through `readListId`. Only ordered read
  /// lists take part: "next book" has no meaning in an unordered one.
  /// - Returns: `true` when the reading state was written.
  @discardableResult
  func recordReadListReading(
    readListId: String,
    bookId: String,
    instanceId: String,
    at date: Date
  ) -> Bool {
    guard !readListId.isEmpty, !bookId.isEmpty, !instanceId.isEmpty else { return false }
    do {
      return try write { db in
        guard let readList = try fetchReadListRecord(db: db, id: readListId, instanceId: instanceId),
          readList.ordered
        else { return false }
        try ReadListReadingState(
          instanceId: instanceId,
          readListId: readListId,
          lastReadBookId: bookId,
          lastReadAt: date,
          needsUpload: true,
          isStopped: false
        ).insert(db)
        return true
      }
    } catch {
      logger.error("Failed to record read list reading: \(error)")
      return false
    }
  }

  /// Clears `needsUpload` for states the server accepted, unless the row changed
  /// while the request was in flight — that newer change must stay pending.
  func markReadListReadingUploaded(_ uploaded: [ReadListReadingState]) {
    guard !uploaded.isEmpty else { return }
    do {
      try write { db in
        for state in uploaded {
          guard
            var current = try fetchReadListReadingState(
              db: db, readListId: state.readListId, instanceId: state.instanceId),
            current.lastReadAt == state.lastReadAt,
            current.lastReadBookId == state.lastReadBookId,
            !current.isStopped
          else { continue }
          current.needsUpload = false
          try current.insert(db)
        }
      }
    } catch {
      logger.error("Failed to mark read list reading uploaded: \(error)")
    }
  }

  /// Marks a read list as no longer being read. The row stays as a tombstone
  /// until the server key is deleted, carrying the stop time so a stop and a
  /// read on another device resolve to whichever happened last.
  func stopReadListReading(readListId: String, instanceId: String, at date: Date) {
    do {
      try write { db in
        guard var state = try fetchReadListReadingState(db: db, readListId: readListId, instanceId: instanceId)
        else { return }
        state.isStopped = true
        state.needsUpload = true
        state.lastReadAt = date
        try state.insert(db)
      }
    } catch {
      logger.error("Failed to stop read list reading: \(error)")
    }
  }

  /// Removes tombstones once their server keys are deleted. A read list started
  /// again in the meantime is no longer stopped and is kept.
  func deleteStoppedReadListReadingStates(readListIds: [String], instanceId: String) {
    guard !readListIds.isEmpty else { return }
    do {
      try write { db in
        _ =
          try ReadListReadingState
          .filter(Column("instance_id") == instanceId)
          .filter(readListIds.contains(Column("read_list_id")))
          .filter(Column("is_stopped") == true)
          .deleteAll(db)
      }
    } catch {
      logger.error("Failed to delete stopped read list reading states: \(error)")
    }
  }

  /// Merges the server's copy into the local reading states, keyed by read list
  /// id. Each read list keeps its most recent change, a read or a stop, so a
  /// read on another device after a local stop resumes the list; local changes
  /// that win stay pending for upload. A local row the server no longer has
  /// was stopped on another device, unless it is a local change not uploaded.
  func applyRemoteReadListReadingStates(
    _ remote: [String: (bookId: String, readAt: Date)],
    instanceId: String
  ) {
    guard !instanceId.isEmpty else { return }
    do {
      try write { db in
        let locals =
          try ReadListReadingState
          .filter(Column("instance_id") == instanceId)
          .fetchAll(db)
        var localById: [String: ReadListReadingState] = [:]
        for local in locals {
          localById[local.readListId] = local
        }

        for local in locals where remote[local.readListId] == nil && !local.needsUpload {
          try local.delete(db)
        }

        for (readListId, entry) in remote {
          if let local = localById[readListId], entry.readAt <= local.lastReadAt { continue }
          try ReadListReadingState(
            instanceId: instanceId,
            readListId: readListId,
            lastReadBookId: entry.bookId,
            lastReadAt: entry.readAt,
            needsUpload: false,
            isStopped: false
          ).insert(db)
        }
      }
    } catch {
      logger.error("Failed to apply remote read list reading states: \(error)")
    }
  }

  /// Resolves every read list the user is reading to the book that represents
  /// it on the dashboard, plus which read list owns each of their books, and
  /// lists every read list being read in the same read.
  ///
  /// Only ordered read lists take part, including in what offers Stop Reading:
  /// a state synced from another device may name one that is unordered here.
  /// Only those with a surfaced book own books: a read list that has not
  /// started, or is finished, never hides a series.
  func fetchReadListReadingSnapshot(
    instanceId: String
  ) -> (snapshot: ReadListReadingSnapshot, activeReadListIds: Set<String>) {
    guard !instanceId.isEmpty else { return (.empty, []) }
    return
      (try? read { db -> (snapshot: ReadListReadingSnapshot, activeReadListIds: Set<String>) in
        let states =
          try ReadListReadingState
          .filter(Column("instance_id") == instanceId)
          .filter(Column("is_stopped") == false)
          .fetchAll(db)

        var readListById: [String: KomgaReadList] = [:]
        for state in states {
          guard let readList = try fetchReadListRecord(db: db, id: state.readListId, instanceId: instanceId),
            readList.ordered
          else { continue }
          readListById[state.readListId] = readList
        }
        let activeReadListIds = Set(readListById.keys)
        guard !readListById.isEmpty else { return (.empty, activeReadListIds) }

        let memberships = try fetchReadListBookMemberships(
          db: db,
          instanceId: instanceId,
          readListIds: Array(readListById.keys)
        )
        var membershipsByReadList: [String: [ReadListBookMembership]] = [:]
        for membership in memberships {
          membershipsByReadList[membership.readListId, default: []].append(membership)
        }
        let books = try fetchBooksByIds(
          db: db,
          ids: Array(Set(memberships.map(\.bookId))),
          instanceId: instanceId
        )
        var bookById: [String: KomgaBook] = [:]
        for book in books {
          bookById[book.bookId] = book
        }

        var continuations: [ReadListContinuation] = []
        var bookIdsByReadList: [String: [String]] = [:]
        for state in states {
          guard let readList = readListById[state.readListId] else { continue }
          let bookIds = (membershipsByReadList[state.readListId] ?? [])
            .sorted { $0.position < $1.position }
            .map(\.bookId)
          guard
            let resolved = resolveReadListContinuation(
              bookIds: bookIds,
              bookById: bookById,
              lastReadBookId: state.lastReadBookId
            )
          else { continue }
          continuations.append(
            ReadListContinuation(
              readListId: readList.readListId,
              readListName: readList.name,
              bookId: resolved.book.bookId,
              libraryId: resolved.book.libraryId,
              placement: resolved.placement,
              lastReadAt: state.lastReadAt
            )
          )
          bookIdsByReadList[readList.readListId] = bookIds
        }
        continuations.sort { $0.lastReadAt > $1.lastReadAt }

        // Most recently read first, so a book in several read lists keeps the
        // owner the user touched last.
        var ownerReadListIdByBookId: [String: String] = [:]
        for continuation in continuations {
          for bookId in bookIdsByReadList[continuation.readListId] ?? []
          where ownerReadListIdByBookId[bookId] == nil {
            ownerReadListIdByBookId[bookId] = continuation.readListId
          }
        }
        let snapshot = ReadListReadingSnapshot(
          continuations: continuations,
          ownerReadListIdByBookId: ownerReadListIdByBookId
        )
        return (snapshot, activeReadListIds)
      }) ?? (.empty, [])
  }

  private func fetchReadListReadingState(
    db: Database,
    readListId: String,
    instanceId: String
  ) throws -> ReadListReadingState? {
    try ReadListReadingState
      .filter(Column("instance_id") == instanceId)
      .filter(Column("read_list_id") == readListId)
      .fetchOne(db)
  }

  /// Picks the book that represents a read list, mirroring Komga's series rules:
  /// a book in progress is Keep Reading; otherwise, once a book is finished, the
  /// next unread book is On Deck.
  ///
  /// Searches forward from the last book read, so a list read out of order
  /// resumes after it, then falls back to the earliest match. A book missing
  /// from the local cache counts as unread so the search never skips past it,
  /// but it cannot represent the list until it is cached.
  nonisolated private func resolveReadListContinuation(
    bookIds: [String],
    bookById: [String: KomgaBook],
    lastReadBookId: String
  ) -> (book: KomgaBook, placement: ReadListContinuation.Placement)? {
    guard !bookIds.isEmpty else { return nil }
    let statuses = bookIds.map { bookId -> Int in
      guard let book = bookById[bookId] else { return 0 }
      return readingStatus(progressCompleted: book.progressCompleted, progressPage: book.progressPage)
    }
    let lastReadIndex = bookIds.firstIndex(of: lastReadBookId)

    func index(ofStatus status: Int, from start: Int?) -> Int? {
      if let start, start < statuses.count,
        let found = statuses[start...].firstIndex(of: status)
      {
        return found
      }
      return statuses.firstIndex(of: status)
    }

    let resolvedIndex: Int
    let placement: ReadListContinuation.Placement
    if let index = index(ofStatus: 1, from: lastReadIndex) {
      resolvedIndex = index
      placement = .keepReading
    } else if statuses.contains(2), let index = index(ofStatus: 0, from: lastReadIndex.map { $0 + 1 }) {
      resolvedIndex = index
      placement = .onDeck
    } else {
      return nil
    }
    guard let book = bookById[bookIds[resolvedIndex]] else { return nil }
    return (book, placement)
  }
}
