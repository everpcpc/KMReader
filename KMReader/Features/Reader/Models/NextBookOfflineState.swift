//
// NextBookOfflineState.swift
//
//

enum NextBookOfflineState: Equatable {
  /// 0...1 while bytes stream in; nil while the download is queued or starting.
  case downloading(bookId: String, progress: Double?)
  /// The next book is fully available offline.
  case ready(bookId: String)
}
