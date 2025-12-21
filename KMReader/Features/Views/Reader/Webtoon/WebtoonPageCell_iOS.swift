//
//  WebtoonPageCell_iOS.swift
//  Komga
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import SDWebImage
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

      imageView.image = nil
      imageView.alpha = 0.0
      loadingIndicator.isHidden = false
      loadingIndicator.startAnimating()
    }

    func setImageURL(_ url: URL, imageSize _: CGSize?) {
      imageView.sd_setImage(
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
            self.imageView.image = nil
            self.imageView.alpha = 0.0
            self.loadingIndicator.stopAnimating()
          } else if image != nil {
            self.loadingIndicator.stopAnimating()
            UIView.animate(withDuration: 0.2) {
              self.imageView.alpha = 1.0
            }
          }
        }
      )
    }

    func showError() {
      imageView.image = nil
      imageView.alpha = 0.0
      loadingIndicator.stopAnimating()
    }

    override func prepareForReuse() {
      super.prepareForReuse()
      imageView.sd_cancelCurrentImageLoad()
      imageView.image = nil
      imageView.alpha = 0.0
      loadingIndicator.stopAnimating()
      loadingIndicator.isHidden = true
      pageIndex = -1
      loadImage = nil
    }
  }
#endif
