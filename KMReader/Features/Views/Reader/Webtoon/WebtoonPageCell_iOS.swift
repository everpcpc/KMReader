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

      loadingIndicator.color = .white
      loadingIndicator.hidesWhenStopped = true
      loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview(loadingIndicator)

      NSLayoutConstraint.activate([
        imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
        imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      ])
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
      UIView.animate(withDuration: 0.2) {
        self.imageView.alpha = 1.0
      }
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
    }
  }
#endif
