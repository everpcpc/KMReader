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
    private let errorLabel = UILabel()
    private var pageIndex: Int = -1
    private var loadImage: ((Int) async -> Void)?

    var readerBackground: ReaderBackground = .system {
      didSet { applyBackground() }
    }

    var showPageNumber: Bool = true {
      didSet { pageMarkerLabel.isHidden = !showPageNumber }
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
      imageView.contentMode = .scaleToFill
      imageView.clipsToBounds = true
      imageView.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview(imageView)

      pageMarkerLabel.font = .systemFont(ofSize: PlatformHelper.pageNumberFontSize, weight: .semibold)
      pageMarkerLabel.textColor = .white
      pageMarkerLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
      pageMarkerLabel.layer.cornerRadius = 6
      pageMarkerLabel.layer.masksToBounds = true
      pageMarkerLabel.textAlignment = .center
      pageMarkerLabel.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview(pageMarkerLabel)

      loadingIndicator.color = .white
      loadingIndicator.hidesWhenStopped = true
      loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview(loadingIndicator)

      errorLabel.font = .systemFont(ofSize: 32)
      errorLabel.textColor = .systemRed
      errorLabel.text = "⚠"
      errorLabel.textAlignment = .center
      errorLabel.isHidden = true
      errorLabel.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview(errorLabel)

      NSLayoutConstraint.activate([
        imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
        imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

        pageMarkerLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
        pageMarkerLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
        pageMarkerLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 30),
        pageMarkerLabel.heightAnchor.constraint(equalToConstant: 24),

        loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

        errorLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        errorLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      ])
    }

    private func applyBackground() {
      contentView.backgroundColor = UIColor(readerBackground.color)
      imageView.backgroundColor = UIColor(readerBackground.color)
    }

    func configure(
      pageIndex: Int, image: UIImage?, showPageNumber: Bool, loadImage: @escaping (Int) async -> Void
    ) {
      self.pageIndex = pageIndex
      self.loadImage = loadImage
      pageMarkerLabel.text = "\(pageIndex + 1)"
      pageMarkerLabel.isHidden = !showPageNumber

      if let image = image {
        // Instant display if image is provided
        imageView.image = image
        imageView.alpha = 1.0
        loadingIndicator.stopAnimating()
        loadingIndicator.isHidden = true
        errorLabel.isHidden = true
      } else {
        imageView.image = nil
        imageView.alpha = 0.0
        errorLabel.isHidden = true
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
      errorLabel.isHidden = false
    }

    override func prepareForReuse() {
      super.prepareForReuse()
      imageView.image = nil
      imageView.alpha = 0.0
      loadingIndicator.stopAnimating()
      loadingIndicator.isHidden = true
      errorLabel.isHidden = true
      pageIndex = -1
      loadImage = nil
      pageMarkerLabel.isHidden = true
    }
  }
#endif
