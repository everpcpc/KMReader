//
//  SaveImageStatus.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

enum SaveImageStatus: Equatable {
  case idle
  case saving
  case success
  case failed(String)
}
