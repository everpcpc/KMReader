//
//  WebtoonFooterCell_macOS.swift
//  Komga
//
//

#if os(macOS)
  import AppKit
  import SwiftUI

  class WebtoonFooterCell: NSCollectionViewItem {
    var readerBackground: ReaderBackground = .system {
      didSet { applyBackground() }
    }

    override func loadView() {
      view = NSView()
      view.wantsLayer = true
      setupUI()
    }

    private func setupUI() {
      applyBackground()
    }

    private func applyBackground() {
      view.layer?.backgroundColor = NSColor(readerBackground.color).cgColor
    }
  }
#endif
