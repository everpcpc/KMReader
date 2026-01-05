//
//  WebtoonPageCell_macOS.swift
//  Komga
//
//  Created by Komga iOS Client
//

#if os(macOS)
  import AppKit
  import SwiftUI

  class WebtoonPageCell: NSCollectionViewItem {
    private let pageImageView = NSImageView()
    private let loadingIndicator = NSProgressIndicator()
    private let pageMarkerContainer = NSView()
    private let pageMarkerLabel = NSTextField(labelWithString: "")
    private var pageIndex: Int = -1
    private var loadImage: ((Int) async -> Void)?

    var readerBackground: ReaderBackground = .system {
      didSet { applyBackground() }
    }

    override func loadView() {
      let containerView = FlippedView()
      containerView.wantsLayer = true
      view = containerView
      setupUI()
    }

    private func setupUI() {
      applyBackground()
      pageImageView.imageScaling = .scaleProportionallyUpOrDown
      pageImageView.wantsLayer = true
      pageImageView.imageAlignment = .alignCenter
      pageImageView.autoresizingMask = [.width, .height]
      pageImageView.frame = view.bounds
      view.addSubview(pageImageView)

      pageMarkerContainer.wantsLayer = true
      pageMarkerContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
      pageMarkerContainer.layer?.cornerRadius = 8
      pageMarkerContainer.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(pageMarkerContainer)

      let baseFont = NSFont.systemFont(ofSize: 16, weight: .semibold)
      if let descriptor = baseFont.fontDescriptor.withDesign(.rounded) {
        pageMarkerLabel.font = NSFont(descriptor: descriptor, size: 16)
      } else {
        pageMarkerLabel.font = baseFont
      }
      pageMarkerLabel.textColor = .white
      pageMarkerLabel.alignment = .center
      pageMarkerLabel.translatesAutoresizingMaskIntoConstraints = false
      pageMarkerContainer.addSubview(pageMarkerLabel)

      loadingIndicator.style = .spinning
      loadingIndicator.controlSize = .small
      loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
      loadingIndicator.isDisplayedWhenStopped = false
      view.addSubview(loadingIndicator)

      NSLayoutConstraint.activate([
        pageMarkerContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
        pageMarkerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
        pageMarkerLabel.topAnchor.constraint(equalTo: pageMarkerContainer.topAnchor, constant: 6),
        pageMarkerLabel.bottomAnchor.constraint(
          equalTo: pageMarkerContainer.bottomAnchor, constant: -6),
        pageMarkerLabel.leadingAnchor.constraint(
          equalTo: pageMarkerContainer.leadingAnchor, constant: 12),
        pageMarkerLabel.trailingAnchor.constraint(
          equalTo: pageMarkerContainer.trailingAnchor, constant: -12),
        loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      ])
    }

    override func viewDidLayout() {
      super.viewDidLayout()
      pageImageView.frame = view.bounds
    }

    private class FlippedView: NSView {
      override var isFlipped: Bool { true }
    }

    private func applyBackground() {
      view.layer?.backgroundColor = NSColor(readerBackground.color).cgColor
      pageImageView.layer?.backgroundColor = NSColor(readerBackground.color).cgColor
    }

    func configure(
      pageIndex: Int, image: NSImage?, loadImage: @escaping (Int) async -> Void
    ) {
      self.pageIndex = pageIndex
      self.loadImage = loadImage
      pageMarkerLabel.stringValue = "\(pageIndex + 1)"
      pageMarkerContainer.isHidden = !AppConfig.showPageNumber

      if let image = image {
        // Instant display if image is provided
        pageImageView.image = image
        pageImageView.alphaValue = 1.0
        loadingIndicator.stopAnimation(nil)
      } else {
        pageImageView.image = nil
        pageImageView.alphaValue = 0.0
        loadingIndicator.startAnimation(nil)
      }
    }

    /// Set image directly from preloaded cache
    func setImage(_ image: NSImage) {
      loadingIndicator.stopAnimation(nil)
      pageImageView.image = image
      pageImageView.alphaValue = 1.0
    }

    /// Load image from URL and return its size (fallback for non-preloaded images)
    func loadImageFromURL(_ url: URL) async -> CGSize? {
      let image = await Task.detached(priority: .userInitiated) {
        guard let data = try? Data(contentsOf: url) else { return nil as NSImage? }
        return NSImage(data: data)
      }.value

      if let image = image {
        self.setImage(image)
        // Return pixel dimensions for accurate layout
        if let rep = image.representations.first {
          return CGSize(width: CGFloat(rep.pixelsWide), height: CGFloat(rep.pixelsHigh))
        }
        return image.size
      } else {
        self.showError()
        return nil
      }
    }

    func showError() {
      pageImageView.image = nil
      pageImageView.alphaValue = 0.0
      loadingIndicator.stopAnimation(nil)
    }

    override func prepareForReuse() {
      super.prepareForReuse()
      pageImageView.image = nil
      pageImageView.alphaValue = 0.0
      loadingIndicator.stopAnimation(nil)
      pageIndex = -1
      loadImage = nil
      pageMarkerContainer.isHidden = true
    }
  }
#endif
