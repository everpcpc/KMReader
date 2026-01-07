//
//  WebtoonConstants.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

enum WebtoonConstants {
  static let initialScrollDelay: TimeInterval = 0.3
  static let initialScrollRetryDelay: TimeInterval = 0.15
  static let initialScrollMaxRetries: Int = 8
  static let layoutReadyDelay: TimeInterval = 0.2
  static let bottomThreshold: CGFloat = 60
  static let footerHeight: CGFloat = 480
  static let footerPadding: CGFloat = 120
  static let scrollAmountMultiplier: CGFloat = 0.8

  static var topAreaThreshold: CGFloat { AppConfig.tapZoneSize.value }
  static var bottomAreaThreshold: CGFloat { 1.0 - AppConfig.tapZoneSize.value }
  static var centerAreaMin: CGFloat { AppConfig.tapZoneSize.value }
  static var centerAreaMax: CGFloat { 1.0 - AppConfig.tapZoneSize.value }
}
