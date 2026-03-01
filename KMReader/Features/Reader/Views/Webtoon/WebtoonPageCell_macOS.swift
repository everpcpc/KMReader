//
// WebtoonPageCell_macOS.swift
//
//

#if os(macOS)
  import AppKit
  import SwiftUI

  class WebtoonPageCell: NSCollectionViewItem {
    private let pageImageView = NSImageView()
    private let sepiaOverlayView = NSView()
    private let loadingIndicator = NSProgressIndicator()
    private let pageMarkerLabel = NSTextField(labelWithString: "")
    private let pageMarkerContainer = NSView()
    private let errorLabel = NSTextField(labelWithString: "⚠")

    var readerBackground: ReaderBackground = .system {
      didSet {
        applyBackground()
      }
    }

    var showPageNumber: Bool = true {
      didSet { pageMarkerContainer.isHidden = !showPageNumber }
    }

    override func loadView() {
      let containerView = FlippedView()
      containerView.wantsLayer = true
      view = containerView
      setupUI()
    }

    private func setupUI() {
      applyBackground()
      pageImageView.imageScaling = .scaleAxesIndependently
      pageImageView.wantsLayer = true
      pageImageView.imageAlignment = .alignCenter
      pageImageView.autoresizingMask = [.width, .height]
      pageImageView.frame = view.bounds
      view.addSubview(pageImageView)

      sepiaOverlayView.wantsLayer = true
      sepiaOverlayView.isHidden = true
      sepiaOverlayView.autoresizingMask = [.width, .height]
      sepiaOverlayView.frame = view.bounds
      view.addSubview(sepiaOverlayView)

      pageMarkerContainer.wantsLayer = true
      pageMarkerContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
      pageMarkerContainer.layer?.cornerRadius = 6
      pageMarkerContainer.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(pageMarkerContainer)

      pageMarkerLabel.wantsLayer = true
      pageMarkerLabel.font = .systemFont(ofSize: PlatformHelper.pageNumberFontSize, weight: .semibold)
      pageMarkerLabel.textColor = .white
      pageMarkerLabel.drawsBackground = false
      pageMarkerLabel.alignment = .center
      pageMarkerLabel.translatesAutoresizingMaskIntoConstraints = false
      pageMarkerContainer.addSubview(pageMarkerLabel)

      loadingIndicator.style = .spinning
      loadingIndicator.controlSize = .small
      loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
      loadingIndicator.isDisplayedWhenStopped = false
      view.addSubview(loadingIndicator)

      errorLabel.font = .systemFont(ofSize: 32)
      errorLabel.textColor = .systemRed
      errorLabel.alignment = .center
      errorLabel.drawsBackground = false
      errorLabel.isBordered = false
      errorLabel.isHidden = true
      errorLabel.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(errorLabel)

      NSLayoutConstraint.activate([
        pageMarkerContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
        pageMarkerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
        pageMarkerContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 30),
        pageMarkerContainer.heightAnchor.constraint(equalToConstant: 24),

        pageMarkerLabel.centerXAnchor.constraint(equalTo: pageMarkerContainer.centerXAnchor),
        pageMarkerLabel.centerYAnchor.constraint(equalTo: pageMarkerContainer.centerYAnchor),
        pageMarkerLabel.leadingAnchor.constraint(equalTo: pageMarkerContainer.leadingAnchor, constant: 4),
        pageMarkerLabel.trailingAnchor.constraint(equalTo: pageMarkerContainer.trailingAnchor, constant: -4),

        loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

        errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      ])
    }

    override func viewDidLayout() {
      super.viewDidLayout()
      pageImageView.frame = view.bounds
      sepiaOverlayView.frame = view.bounds
    }

    private class FlippedView: NSView {
      override var isFlipped: Bool { true }
    }

    private func applyBackground() {
      view.layer?.backgroundColor = NSColor(readerBackground.color).cgColor
      pageImageView.layer?.backgroundColor = NSColor(readerBackground.color).cgColor
      updateSepiaOverlay()
    }

    private func updateSepiaOverlay() {
      guard readerBackground.appliesImageMultiplyBlend else {
        sepiaOverlayView.isHidden = true
        sepiaOverlayView.layer?.compositingFilter = nil
        sepiaOverlayView.layer?.backgroundColor = NSColor.clear.cgColor
        return
      }
      sepiaOverlayView.isHidden = false
      sepiaOverlayView.layer?.backgroundColor = NSColor(readerBackground.color).cgColor
      sepiaOverlayView.layer?.compositingFilter = "multiplyBlendMode"
    }

    func configure(
      pageLabel: String,
      image: NSImage?,
      showPageNumber: Bool
    ) {
      pageMarkerLabel.stringValue = pageLabel
      pageMarkerContainer.isHidden = !showPageNumber

      if let image = image {
        // Instant display if image is provided
        setImage(image)
      } else {
        pageImageView.image = nil
        pageImageView.alphaValue = 0.0
        errorLabel.isHidden = true
        loadingIndicator.startAnimation(nil)
      }
    }

    /// Set image directly from preloaded cache
    func setImage(_ image: NSImage) {
      loadingIndicator.stopAnimation(nil)
      errorLabel.isHidden = true
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
      errorLabel.isHidden = false
    }

    override func prepareForReuse() {
      super.prepareForReuse()
      pageImageView.image = nil
      pageImageView.alphaValue = 0.0
      loadingIndicator.stopAnimation(nil)
      errorLabel.isHidden = true
      pageMarkerContainer.isHidden = true
    }
  }
#endif
