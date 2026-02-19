//
//  SaveImageStatus.swift
//  Komga
//
//

import Foundation

enum SaveImageStatus: Equatable {
  case idle
  case saving
  case success
  case failed(String)
}
