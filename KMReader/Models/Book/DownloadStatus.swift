//
//  DownloadStatus.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

/// Status of an offline book download.
enum DownloadStatus: Equatable, Sendable {
  case notDownloaded
  case downloading(progress: Double)
  case downloaded
  case failed(error: String)
}
