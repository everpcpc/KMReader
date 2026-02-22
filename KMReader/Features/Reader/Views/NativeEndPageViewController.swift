//
// NativeEndPageViewController.swift
//

#if os(iOS)
  import SwiftUI
  import UIKit

  @MainActor
  final class NativeEndPageViewController: UIViewController {
    private var nextBook: Book?
    private var readListContext: ReaderReadListContext?
    private var readingDirection: ReadingDirection = .ltr
    private var renderConfig = ReaderRenderConfig(
      tapZoneSize: .large,
      tapZoneMode: .auto,
      showPageNumber: true,
      readerBackground: .system,
      enableLiveText: false,
      doubleTapZoomScale: 3.0,
      doubleTapZoomMode: .fast
    )
    private var showImage = true

    private var onDismiss: (() -> Void)?
    private var onNextBook: ((String) -> Void)?

    private let contentStack = UIStackView()
    private let infoStack = UIStackView()
    private let nextBookStack = UIStackView()
    private let upNextLabel = UILabel()
    private let coverViewController = NativeBookCoverViewController()
    private let metadataStack = UIStackView()
    private let titleLabel = UILabel()
    private let readListRow = UIStackView()
    private let readListIconView = UIImageView()
    private let readListNameLabel = UILabel()
    private let seriesLabel = UILabel()
    private let detailRow = UIStackView()
    private let pagesLabel = UILabel()
    private let separatorLabel = UILabel()
    private let sizeLabel = UILabel()

    private let caughtUpStack = UIStackView()
    private let caughtUpIconView = UIImageView()
    private let caughtUpLabel = UILabel()

    private let buttonStack = UIStackView()
    private let closeButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)

    private var nextBookID: String?

    func configure(
      nextBook: Book?,
      readListContext: ReaderReadListContext?,
      readingDirection: ReadingDirection,
      renderConfig: ReaderRenderConfig,
      showImage: Bool = true,
      onDismiss: @escaping () -> Void,
      onNextBook: @escaping (String) -> Void
    ) {
      self.nextBook = nextBook
      self.readListContext = readListContext
      self.readingDirection = readingDirection
      self.renderConfig = renderConfig
      self.showImage = showImage
      self.onDismiss = onDismiss
      self.onNextBook = onNextBook
      self.nextBookID = nextBook?.id

      if isViewLoaded {
        applyConfiguration()
      }
    }

    override func viewDidLoad() {
      super.viewDidLoad()
      setupUI()
      applyConfiguration()
    }

    private func setupUI() {
      view.backgroundColor = UIColor(renderConfig.readerBackground.color)

      contentStack.translatesAutoresizingMaskIntoConstraints = false
      contentStack.axis = .vertical
      contentStack.alignment = .center
      contentStack.spacing = 24
      view.addSubview(contentStack)

      infoStack.axis = .vertical
      infoStack.alignment = .fill
      infoStack.spacing = 24
      infoStack.isLayoutMarginsRelativeArrangement = true
      infoStack.layoutMargins = UIEdgeInsets(top: 32, left: 24, bottom: 32, right: 24)
      infoStack.isUserInteractionEnabled = false
      contentStack.addArrangedSubview(infoStack)

      nextBookStack.axis = .vertical
      nextBookStack.alignment = .center
      nextBookStack.spacing = 16
      infoStack.addArrangedSubview(nextBookStack)

      upNextLabel.numberOfLines = 0
      upNextLabel.textAlignment = .center
      upNextLabel.adjustsFontForContentSizeCategory = true
      nextBookStack.addArrangedSubview(upNextLabel)

      addChild(coverViewController)
      coverViewController.view.translatesAutoresizingMaskIntoConstraints = false
      nextBookStack.addArrangedSubview(coverViewController.view)
      coverViewController.didMove(toParent: self)

      metadataStack.axis = .vertical
      metadataStack.alignment = .center
      metadataStack.spacing = 4
      nextBookStack.addArrangedSubview(metadataStack)

      titleLabel.numberOfLines = 0
      titleLabel.textAlignment = .center
      titleLabel.adjustsFontForContentSizeCategory = true
      metadataStack.addArrangedSubview(titleLabel)

      readListRow.axis = .horizontal
      readListRow.alignment = .center
      readListRow.spacing = 4
      metadataStack.addArrangedSubview(readListRow)

      readListIconView.image = UIImage(systemName: ContentIcon.readList)
      readListIconView.tintColor = .secondaryLabel
      readListIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .caption1)
      readListIconView.setContentCompressionResistancePriority(.required, for: .horizontal)
      readListRow.addArrangedSubview(readListIconView)

      readListNameLabel.numberOfLines = 1
      readListNameLabel.adjustsFontForContentSizeCategory = true
      readListRow.addArrangedSubview(readListNameLabel)

      seriesLabel.numberOfLines = 1
      seriesLabel.textAlignment = .center
      seriesLabel.adjustsFontForContentSizeCategory = true
      metadataStack.addArrangedSubview(seriesLabel)

      detailRow.axis = .horizontal
      detailRow.alignment = .center
      detailRow.spacing = 4
      metadataStack.addArrangedSubview(detailRow)

      pagesLabel.adjustsFontForContentSizeCategory = true
      detailRow.addArrangedSubview(pagesLabel)

      separatorLabel.text = "•"
      separatorLabel.adjustsFontForContentSizeCategory = true
      detailRow.addArrangedSubview(separatorLabel)

      sizeLabel.adjustsFontForContentSizeCategory = true
      detailRow.addArrangedSubview(sizeLabel)

      caughtUpStack.axis = .vertical
      caughtUpStack.alignment = .center
      caughtUpStack.spacing = 12
      caughtUpStack.isLayoutMarginsRelativeArrangement = true
      caughtUpStack.layoutMargins = UIEdgeInsets(top: 40, left: 0, bottom: 40, right: 0)
      infoStack.addArrangedSubview(caughtUpStack)

      caughtUpIconView.image = UIImage(systemName: "checkmark.circle.fill")
      caughtUpIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 40, weight: .regular)
      caughtUpIconView.tintColor = .tintColor
      caughtUpStack.addArrangedSubview(caughtUpIconView)

      caughtUpLabel.numberOfLines = 0
      caughtUpLabel.textAlignment = .center
      caughtUpLabel.adjustsFontForContentSizeCategory = true
      caughtUpStack.addArrangedSubview(caughtUpLabel)

      buttonStack.axis = .horizontal
      buttonStack.alignment = .center
      buttonStack.spacing = 16
      contentStack.addArrangedSubview(buttonStack)

      closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
      nextButton.addTarget(self, action: #selector(handleNextBook), for: .touchUpInside)

      buttonStack.addArrangedSubview(closeButton)
      buttonStack.addArrangedSubview(nextButton)

      NSLayoutConstraint.activate([
        contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
        contentStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
        contentStack.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
        contentStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
        contentStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        contentStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        infoStack.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -80),
        nextBookStack.widthAnchor.constraint(lessThanOrEqualTo: infoStack.widthAnchor),
        titleLabel.widthAnchor.constraint(lessThanOrEqualTo: infoStack.widthAnchor),
        coverViewController.view.widthAnchor.constraint(equalToConstant: 120),
        coverViewController.view.heightAnchor.constraint(equalToConstant: 160),
      ])
    }

    private func applyConfiguration() {
      let textColor = contentColor
      view.backgroundColor = UIColor(renderConfig.readerBackground.color)
      let directionAttribute: UISemanticContentAttribute =
        readingDirection == .rtl ? .forceRightToLeft : .forceLeftToRight
      view.semanticContentAttribute = directionAttribute
      contentStack.semanticContentAttribute = directionAttribute
      buttonStack.semanticContentAttribute = directionAttribute
      infoStack.semanticContentAttribute = .forceLeftToRight

      upNextLabel.font = preferredFont(textStyle: .title3, design: .rounded, weight: .semibold)
      titleLabel.font = preferredFont(textStyle: .title3, design: .serif, weight: .bold)
      readListNameLabel.font = preferredFont(textStyle: .subheadline, design: .serif)
      seriesLabel.font = preferredFont(textStyle: .subheadline, design: .serif)
      pagesLabel.font = .preferredFont(forTextStyle: .caption1)
      separatorLabel.font = .preferredFont(forTextStyle: .caption1)
      sizeLabel.font = .preferredFont(forTextStyle: .caption1)
      caughtUpLabel.font = .preferredFont(forTextStyle: .headline)

      upNextLabel.textColor = textColor.withAlphaComponent(0.9)
      titleLabel.textColor = textColor
      readListIconView.tintColor = textColor.withAlphaComponent(0.7)
      readListNameLabel.textColor = textColor.withAlphaComponent(0.7)
      seriesLabel.textColor = textColor.withAlphaComponent(0.7)
      pagesLabel.textColor = textColor.withAlphaComponent(0.5)
      separatorLabel.textColor = textColor.withAlphaComponent(0.5)
      sizeLabel.textColor = textColor.withAlphaComponent(0.5)
      caughtUpLabel.textColor = textColor

      if let nextBook {
        nextBookStack.isHidden = false
        caughtUpStack.isHidden = true

        upNextLabel.text = upNextText(for: nextBook)
        titleLabel.text = nextBook.metadata.title
        pagesLabel.text = "\(nextBook.media.pagesCount) pages"
        sizeLabel.text = nextBook.size

        if let readListContext {
          readListRow.isHidden = false
          seriesLabel.isHidden = true
          readListNameLabel.text = readListContext.name
        } else {
          readListRow.isHidden = true
          seriesLabel.isHidden = false
          seriesLabel.text = nextBook.seriesTitle
        }

        coverViewController.view.isHidden = !showImage
        coverViewController.configure(bookID: showImage ? nextBook.id : nil)
      } else {
        nextBookStack.isHidden = true
        caughtUpStack.isHidden = false
        caughtUpLabel.text = String(localized: "You're all caught up!")
        coverViewController.configure(bookID: nil)
      }

      var closeConfig = borderedButtonConfiguration()
      closeConfig.image = UIImage(systemName: "xmark")
      closeConfig.imagePlacement = .leading
      closeConfig.imagePadding = 8
      closeConfig.preferredSymbolConfigurationForImage = buttonSymbolConfiguration
      closeConfig.title = String(localized: "Close")
      closeConfig.cornerStyle = .capsule
      closeButton.configuration = closeConfig
      closeButton.tintColor = textColor

      var nextConfig = borderedButtonConfiguration()
      nextConfig.image = UIImage(systemName: nextArrowSymbolName)
      nextConfig.imagePlacement = .trailing
      nextConfig.imagePadding = 8
      nextConfig.preferredSymbolConfigurationForImage = buttonSymbolConfiguration
      nextConfig.title = String(localized: "reader.nextBook")
      nextConfig.cornerStyle = .capsule
      nextButton.configuration = nextConfig
      nextButton.tintColor = textColor
      nextButton.isHidden = nextBook == nil
    }

    private func borderedButtonConfiguration() -> UIButton.Configuration {
      if #available(iOS 26.0, *) {
        return .glass()
      }
      return .bordered()
    }

    private var nextArrowSymbolName: String {
      readingDirection == .rtl ? "arrow.left" : "arrow.right"
    }

    private var buttonSymbolConfiguration: UIImage.SymbolConfiguration {
      UIImage.SymbolConfiguration(
        textStyle: .body,
        scale: .small
      )
    }

    private var contentColor: UIColor {
      switch renderConfig.readerBackground {
      case .black, .gray:
        return .white
      case .white:
        return .black
      case .system:
        return .label
      }
    }

    private func upNextText(for book: Book) -> String {
      let numberText = "#\(book.metadata.number)"
      if readListContext != nil {
        return String.localizedStringWithFormat(
          String(localized: "UP NEXT IN READ LIST: %@"),
          numberText
        )
        .uppercased()
      }
      return String.localizedStringWithFormat(
        String(localized: "UP NEXT IN SERIES: %@"),
        numberText
      )
      .uppercased()
    }

    private func preferredFont(
      textStyle: UIFont.TextStyle,
      design: UIFontDescriptor.SystemDesign? = nil,
      weight: UIFont.Weight? = nil
    ) -> UIFont {
      var descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: textStyle)
      if let design, let designedDescriptor = descriptor.withDesign(design) {
        descriptor = designedDescriptor
      }
      if let weight {
        descriptor = descriptor.addingAttributes([
          UIFontDescriptor.AttributeName.traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
      }
      return UIFont(descriptor: descriptor, size: 0)
    }

    @objc private func handleClose() {
      onDismiss?()
    }

    @objc private func handleNextBook() {
      guard let nextBookID else { return }
      onNextBook?(nextBookID)
    }
  }
#endif
