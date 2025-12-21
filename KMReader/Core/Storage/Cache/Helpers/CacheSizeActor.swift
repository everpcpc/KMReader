//
//  CacheSizeActor.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

/// Actor for thread-safe cache size and count management
actor CacheSizeActor {
  var cachedSize: Int64?
  var cachedCount: Int?
  var isValid = false

  func get() -> (size: Int64?, count: Int?, isValid: Bool) {
    return (cachedSize, cachedCount, isValid)
  }

  func set(size: Int64, count: Int) {
    cachedSize = size
    cachedCount = count
    isValid = true
  }

  func invalidate() {
    isValid = false
  }

  func updateSize(delta: Int64) {
    if isValid, let currentSize = cachedSize {
      cachedSize = max(0, currentSize + delta)
    } else {
      isValid = false
    }
  }

  func updateCount(delta: Int) {
    if isValid, let currentCount = cachedCount {
      cachedCount = max(0, currentCount + delta)
    } else {
      isValid = false
    }
  }
}
