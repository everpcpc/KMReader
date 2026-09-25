//
// ReadListContinuation.swift
//
//

import Foundation

/// Where a read list the user is reading continues: the book it resumes with
/// (in progress, or the next unread one) and how far along the list is.
nonisolated struct ReadListContinuation: Equatable, Sendable {
  let readListId: String
  let readListName: String
  let bookId: String
  /// Display line of `bookId`: number and title, or the title of a one-shot.
  let bookTitle: String
  /// How much of `bookId` is read while it is in progress; nil while unread.
  let bookProgress: Double?
  /// Offline status of `bookId`, shown as the card's download icon.
  let downloadStatus: DownloadStatus
  let libraryId: String
  let booksRead: Int
  let bookCount: Int
  let lastReadAt: Date
}
