//
//  WebtoonFooterCell_iOS.swift
//  Komga
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import SwiftUI
  import UIKit

  class WebtoonFooterCell: UICollectionViewCell {
    var readerBackground: ReaderBackground = .system {
      didSet { applyBackground() }
    }

    override init(frame: CGRect) {
      super.init(frame: frame)
      setupUI()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
      applyBackground()
    }

    private func applyBackground() {
      contentView.backgroundColor = UIColor(readerBackground.color)
    }
  }
#endif
