//
// PendingNextBookDownload.swift
//
//

struct PendingNextBookDownload: Equatable {
  let bookId: String
  /// 0...1 while bytes stream in; nil while the download is queued or starting.
  let progress: Double?
}
