//
//  WebtoonPageCell_macOS.swift
//  Komga
//
//  Created by Komga iOS Client
//

#if os(macOS)
  import AppKit
  import SDWebImage
  import SwiftUI

  class WebtoonPageCell: NSCollectionViewItem {
    private let pageImageView = NSImageView()
    private let loadingIndicator = NSProgressIndicator()
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

      loadingIndicator.style = .spinning
      loadingIndicator.controlSize = .small
      loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
      loadingIndicator.isDisplayedWhenStopped = false
      view.addSubview(loadingIndicator)

      NSLayoutConstraint.activate([
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

      pageImageView.image = nil
      pageImageView.alphaValue = 0.0
      loadingIndicator.startAnimation(nil)
    }

    func setImageURL(_ url: URL, imageSize _: CGSize?) {
      pageImageView.sd_setImage(
        with: url,
        placeholderImage: nil,
        options: [.retryFailed, .scaleDownLargeImages],
        context: [
          .imageScaleDownLimitBytes: 50 * 1024 * 1024,
          .customManager: SDImageCacheProvider.pageImageManager,
          .storeCacheType: SDImageCacheType.memory.rawValue,
          .queryCacheType: SDImageCacheType.memory.rawValue,
        ],
        progress: nil,
        completed: { [weak self] image, error, _, _ in
          guard let self = self else { return }

          if error != nil {
            self.pageImageView.image = nil
            self.pageImageView.alphaValue = 0.0
            self.loadingIndicator.stopAnimation(nil)
          } else if image != nil {
            self.loadingIndicator.stopAnimation(nil)
            NSAnimationContext.runAnimationGroup { context in
              context.duration = 0.2
              self.pageImageView.animator().alphaValue = 1.0
            }
          }
        }
      )
    }

    func showError() {
      pageImageView.image = nil
      pageImageView.alphaValue = 0.0
      loadingIndicator.stopAnimation(nil)
    }

    override func prepareForReuse() {
      super.prepareForReuse()
      pageImageView.sd_cancelCurrentImageLoad()
      pageImageView.image = nil
      pageImageView.alphaValue = 0.0
      loadingIndicator.stopAnimation(nil)
      pageIndex = -1
      loadImage = nil
    }
  }
#endif
