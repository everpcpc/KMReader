//
//  CoverAspectRatio.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import CoreGraphics

enum CoverAspectRatio {
  static let heightToWidth: CGFloat = CGFloat(Double(2).squareRoot())
  static let widthToHeight: CGFloat = 1 / heightToWidth
}
