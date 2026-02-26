//
// NativeBookCoverViewController.swift
//

#if os(iOS)
  import UIKit

  @MainActor
  final class NativeBookCoverViewController: UIViewController {
    private let coverContainerView = UIView()
    private let coverImageView = UIImageView()

    private var coverImageTask: Task<Void, Never>?
    private var coverImageBookID: String?
    private var failedCoverImageBookID: String?
    private var sourceCoverImage: UIImage?

    var useLightShadow: Bool = false {
      didSet {
        updateShadowAppearance()
      }
    }

    var imageBlendTintColor: UIColor? {
      didSet {
        updateRenderedCoverImage()
      }
    }

    var cornerRadius: CGFloat = 12 {
      didSet {
        updateCoverImageDecoration()
      }
    }

    override func viewDidLoad() {
      super.viewDidLoad()
      setupUI()
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      updateCoverImageDecoration()
    }

    deinit {
      coverImageTask?.cancel()
    }

    func configure(bookID: String?) {
      updateCoverImage(for: bookID)
    }

    private func setupUI() {
      view.backgroundColor = .clear

      coverContainerView.translatesAutoresizingMaskIntoConstraints = false
      coverContainerView.backgroundColor = .clear
      coverContainerView.layer.shadowOpacity = 0
      coverContainerView.layer.shadowOffset = CGSize(width: 0, height: 3)
      coverContainerView.layer.shadowRadius = 6
      view.addSubview(coverContainerView)

      coverImageView.translatesAutoresizingMaskIntoConstraints = false
      coverImageView.contentMode = .scaleAspectFit
      coverImageView.clipsToBounds = true
      coverImageView.layer.cornerRadius = 0
      coverContainerView.addSubview(coverImageView)

      NSLayoutConstraint.activate([
        coverContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        coverContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        coverContainerView.topAnchor.constraint(equalTo: view.topAnchor),
        coverContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        coverImageView.leadingAnchor.constraint(equalTo: coverContainerView.leadingAnchor),
        coverImageView.trailingAnchor.constraint(equalTo: coverContainerView.trailingAnchor),
        coverImageView.topAnchor.constraint(equalTo: coverContainerView.topAnchor),
        coverImageView.bottomAnchor.constraint(equalTo: coverContainerView.bottomAnchor),
      ])

      updateShadowAppearance()
    }

    private func updateCoverImage(for bookID: String?) {
      if coverImageBookID == bookID {
        if coverImageTask != nil || coverImageView.image != nil || failedCoverImageBookID == bookID {
          return
        }
      }

      if coverImageBookID != bookID {
        failedCoverImageBookID = nil
      }

      coverImageTask?.cancel()
      coverImageTask = nil
      coverImageBookID = bookID

      guard let bookID else {
        sourceCoverImage = nil
        coverImageView.image = nil
        coverImageView.layer.mask = nil
        coverImageView.layer.cornerRadius = cornerRadius
        coverImageView.backgroundColor = .clear
        coverContainerView.layer.shadowOpacity = 0
        coverContainerView.layer.shadowPath = nil
        failedCoverImageBookID = nil
        return
      }

      sourceCoverImage = nil
      coverImageView.image = nil
      coverImageView.backgroundColor = .clear
      coverImageView.layer.cornerRadius = 0
      coverContainerView.layer.shadowOpacity = 0
      coverContainerView.layer.shadowPath = nil

      coverImageTask = Task { [weak self] in
        let image = await Self.loadCoverImage(for: bookID)
        guard !Task.isCancelled else { return }
        guard let self else { return }
        guard self.coverImageBookID == bookID else { return }
        self.coverImageTask = nil
        self.sourceCoverImage = image
        self.updateRenderedCoverImage()
        self.failedCoverImageBookID = image == nil ? bookID : nil
        self.coverImageView.layer.cornerRadius = image == nil ? self.cornerRadius : 0
        self.coverImageView.backgroundColor = image == nil ? .secondarySystemFill : .clear
      }
    }

    private func updateRenderedCoverImage() {
      guard let sourceCoverImage else {
        coverImageView.image = nil
        updateCoverImageDecoration()
        return
      }

      if let tintColor = imageBlendTintColor,
        let blendedImage = ReaderImageBlendHelper.multiply(image: sourceCoverImage, tintColor: tintColor)
      {
        coverImageView.image = blendedImage
      } else {
        coverImageView.image = sourceCoverImage
      }
      updateCoverImageDecoration()
    }

    private func updateCoverImageDecoration() {
      guard let image = coverImageView.image, !coverImageView.bounds.isEmpty else {
        coverImageView.layer.mask = nil
        coverContainerView.layer.shadowOpacity = 0
        coverContainerView.layer.shadowPath = nil
        return
      }

      let contentRect = imageContentRect(for: image, in: coverImageView)
      let maskPath = UIBezierPath(
        roundedRect: contentRect,
        cornerRadius: cornerRadius
      )
      let maskLayer = CAShapeLayer()
      maskLayer.path = maskPath.cgPath
      coverImageView.layer.mask = maskLayer

      coverContainerView.layer.shadowOpacity = 0.22
      coverContainerView.layer.shadowPath = maskPath.cgPath
    }

    private func imageContentRect(for image: UIImage, in imageView: UIImageView) -> CGRect {
      let imageSize = image.size
      let viewSize = imageView.bounds.size
      guard imageSize.width > 0, imageSize.height > 0, viewSize.width > 0, viewSize.height > 0 else {
        return imageView.bounds
      }

      let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
      let width = imageSize.width * scale
      let height = imageSize.height * scale
      let x = (viewSize.width - width) / 2
      let y = (viewSize.height - height) / 2
      return CGRect(x: x, y: y, width: width, height: height)
    }

    private func updateShadowAppearance() {
      coverContainerView.layer.shadowColor = effectiveShadowColor.cgColor
    }

    private var effectiveShadowColor: UIColor {
      if useLightShadow {
        return UIColor.white.withAlphaComponent(0.4)
      }
      return UIColor.black.withAlphaComponent(0.35)
    }

    nonisolated private static func loadCoverImage(for bookID: String) async -> UIImage? {
      await Task.detached(priority: .userInitiated) {
        let fileURL = ThumbnailCache.getThumbnailFileURL(id: bookID, type: .book)
        let targetURL: URL?
        if FileManager.default.fileExists(atPath: fileURL.path) {
          targetURL = fileURL
        } else {
          targetURL = try? await ThumbnailCache.shared.ensureThumbnail(id: bookID, type: .book)
        }

        guard !Task.isCancelled, let targetURL else { return nil }
        guard let image = PlatformImage(contentsOfFile: targetURL.path) else { return nil }
        return await ImageDecodeHelper.decodeForDisplay(image)
      }
      .value
    }
  }
#endif
