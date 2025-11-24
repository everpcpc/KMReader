//
//  WebtoonFooterCell.swift
//  Komga
//
//  Created by Komga iOS Client
//

#if canImport(UIKit)
  import Foundation
  import SwiftUI
  import UIKit

  class WebtoonFooterCell: UICollectionViewCell {
    @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system

    override init(frame: CGRect) {
      super.init(frame: frame)
      setupUI()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
      contentView.backgroundColor = UIColor(readerBackground.color)
    }
  }
#endif
