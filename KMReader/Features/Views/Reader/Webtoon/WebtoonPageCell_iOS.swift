//
//  WebtoonPageCell_iOS.swift
//  Komga
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import SwiftUI
  import UIKit

  class WebtoonPageCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let pageMarkerContainer = UIView()
    private let pageMarkerLabel = UILabel()
    private var pageIndex: Int = -1
    private var loadImage: ((Int) async -> Void)?

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
      imageView.contentMode = .scaleAspectFit
      imageView.clipsToBounds = false
      imageView.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview(imageView)

      pageMarkerContainer.backgroundColor = UIColor.black.withAlphaComponent(0.6)
      pageMarkerContainer.layer.cornerRadius = 8
      pageMarkerContainer.layer.masksToBounds = true
      pageMarkerContainer.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview(pageMarkerContainer)

      let baseFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
      if let descriptor = baseFont.fontDescriptor.withDesign(.rounded) {
        pageMarkerLabel.font = UIFont(descriptor: descriptor, size: 16)
      } else {
        pageMarkerLabel.font = baseFont
      }
      pageMarkerLabel.textColor = .white
      pageMarkerLabel.textAlignment = .center
      pageMarkerLabel.translatesAutoresizingMaskIntoConstraints = false
      pageMarkerContainer.addSubview(pageMarkerLabel)

      loadingIndicator.color = .white
      loadingIndicator.hidesWhenStopped = true
      loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview(loadingIndicator)

      NSLayoutConstraint.activate([
        imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
        imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        pageMarkerContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
        pageMarkerContainer.trailingAnchor.constraint(
          equalTo: contentView.trailingAnchor, constant: -12),
        pageMarkerLabel.topAnchor.constraint(equalTo: pageMarkerContainer.topAnchor, constant: 6),
        pageMarkerLabel.bottomAnchor.constraint(
          equalTo: pageMarkerContainer.bottomAnchor, constant: -6),
        pageMarkerLabel.leadingAnchor.constraint(
          equalTo: pageMarkerContainer.leadingAnchor, constant: 12),
        pageMarkerLabel.trailingAnchor.constraint(
          equalTo: pageMarkerContainer.trailingAnchor, constant: -12),
        loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      ])
      pageMarkerLabel.setContentHuggingPriority(.required, for: .horizontal)
      pageMarkerLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func applyBackground() {
      contentView.backgroundColor = UIColor(readerBackground.color)
      imageView.backgroundColor = UIColor(readerBackground.color)
    }

    func configure(
      pageIndex: Int, image: UIImage?, loadImage: @escaping (Int) async -> Void
    ) {
      self.pageIndex = pageIndex
      self.loadImage = loadImage
      pageMarkerLabel.text = "\(pageIndex + 1)"
      pageMarkerContainer.isHidden = !AppConfig.showPageNumber

      if let image = image {
        // Instant display if image is provided
        imageView.image = image
        imageView.alpha = 1.0
        loadingIndicator.stopAnimating()
        loadingIndicator.isHidden = true
      } else {
        imageView.image = nil
        imageView.alpha = 0.0
        loadingIndicator.isHidden = false
        loadingIndicator.startAnimating()
      }
    }

    /// Set image directly from preloaded cache
    func setImage(_ image: UIImage) {
      loadingIndicator.stopAnimating()
      imageView.image = image
      imageView.alpha = 1.0
    }

    /// Load image from URL and return its size (fallback for non-preloaded images)
    func loadImageFromURL(_ url: URL) async -> CGSize? {
      let image = await Task.detached(priority: .userInitiated) {
        guard let data = try? Data(contentsOf: url) else { return nil as UIImage? }
        return UIImage(data: data)
      }.value

      if let image = image {
        self.setImage(image)
        return image.size
      } else {
        self.showError()
        return nil
      }
    }

    func showError() {
      imageView.image = nil
      imageView.alpha = 0.0
      loadingIndicator.stopAnimating()
    }

    override func prepareForReuse() {
      super.prepareForReuse()
      imageView.image = nil
      imageView.alpha = 0.0
      loadingIndicator.stopAnimating()
      loadingIndicator.isHidden = true
      pageIndex = -1
      loadImage = nil
      pageMarkerContainer.isHidden = true
    }
  }
#endif
