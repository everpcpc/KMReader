//
// NativeEndPageViewController.swift
//

#if os(iOS)
  import SwiftUI
  import UIKit

  @MainActor
  final class NativeEndPageViewController: UIViewController, UIGestureRecognizerDelegate {
    private var previousBook: Book?
    private var nextBook: Book?
    private var readListContext: ReaderReadListContext?
    private var readingDirection: ReadingDirection = .ltr
    private var renderConfig = ReaderRenderConfig(
      tapZoneSize: .large,
      tapZoneMode: .auto,
      showPageNumber: true,
      autoPlayAnimatedImages: false,
      readerBackground: .system,
      enableLiveText: false,
      doubleTapZoomScale: 3.0,
      doubleTapZoomMode: .fast
    )
    private var onDismiss: (() -> Void)?
    private var onNextPage: (() -> Void)?
    private var onPreviousPage: (() -> Void)?
    private var onToggleControls: (() -> Void)?
    private var lastIsPortrait: Bool?

    private let contentStack = UIStackView()
    private let relationHeaderLabel = UILabel()
    private let sectionsStack = UIStackView()

    private let previousContainer = UIView()
    private let previousStack = UIStackView()
    private let previousBadgeLabel = UILabel()
    private let previousCoverViewController = NativeBookCoverViewController()
    private let previousTitleLabel = UILabel()
    private let previousDetailLabel = UILabel()

    private let nextContainer = UIView()
    private let nextStack = UIStackView()
    private let nextBadgeLabel = UILabel()
    private let nextCoverViewController = NativeBookCoverViewController()
    private let nextMetadataStack = UIStackView()
    private let nextTitleLabel = UILabel()
    private let nextDetailLabel = UILabel()
    private let caughtUpStack = UIStackView()
    private let caughtUpIconView = UIImageView()
    private let caughtUpLabel = UILabel()

    private let horizontalDividerStack = UIStackView()
    private let leadingDivider = UIView()
    private let dividerTitleLabel = UILabel()
    private let trailingDivider = UIView()
    private let verticalDivider = UIView()

    private let buttonStack = UIStackView()
    private let closeButton = UIButton(type: .system)
    private var sectionsEqualWidthConstraint: NSLayoutConstraint?

    func configure(
      previousBook: Book?,
      nextBook: Book?,
      readListContext: ReaderReadListContext?,
      readingDirection: ReadingDirection,
      renderConfig: ReaderRenderConfig,
      onNextPage: (() -> Void)? = nil,
      onPreviousPage: (() -> Void)? = nil,
      onToggleControls: (() -> Void)? = nil,
      onDismiss: @escaping () -> Void
    ) {
      self.previousBook = previousBook
      self.nextBook = nextBook
      self.readListContext = readListContext
      self.readingDirection = readingDirection
      self.renderConfig = renderConfig
      self.onNextPage = onNextPage
      self.onPreviousPage = onPreviousPage
      self.onToggleControls = onToggleControls
      self.onDismiss = onDismiss

      if isViewLoaded {
        applyConfiguration()
      }
    }

    override func viewDidLoad() {
      super.viewDidLoad()
      setupUI()
      applyConfiguration()
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      applyLayoutModeIfNeeded()
    }

    private func setupUI() {
      view.backgroundColor = UIColor(renderConfig.readerBackground.color)

      let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
      singleTap.cancelsTouchesInView = false
      singleTap.delegate = self
      view.addGestureRecognizer(singleTap)

      contentStack.translatesAutoresizingMaskIntoConstraints = false
      contentStack.axis = .vertical
      contentStack.alignment = .fill
      contentStack.spacing = 20
      contentStack.isLayoutMarginsRelativeArrangement = true
      contentStack.layoutMargins = UIEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
      view.addSubview(contentStack)

      relationHeaderLabel.numberOfLines = 1
      relationHeaderLabel.textAlignment = .center
      relationHeaderLabel.adjustsFontForContentSizeCategory = true
      contentStack.addArrangedSubview(relationHeaderLabel)

      sectionsStack.axis = .vertical
      sectionsStack.alignment = .fill
      sectionsStack.spacing = 20
      sectionsStack.isUserInteractionEnabled = false
      contentStack.addArrangedSubview(sectionsStack)

      previousContainer.translatesAutoresizingMaskIntoConstraints = false
      previousStack.translatesAutoresizingMaskIntoConstraints = false
      previousStack.axis = .vertical
      previousStack.alignment = .center
      previousStack.spacing = 6
      previousContainer.addSubview(previousStack)

      previousBadgeLabel.numberOfLines = 1
      previousBadgeLabel.textAlignment = .center
      previousBadgeLabel.adjustsFontForContentSizeCategory = true
      previousStack.addArrangedSubview(previousBadgeLabel)

      addChild(previousCoverViewController)
      previousCoverViewController.view.translatesAutoresizingMaskIntoConstraints = false
      previousStack.addArrangedSubview(previousCoverViewController.view)
      previousCoverViewController.didMove(toParent: self)

      previousTitleLabel.numberOfLines = 2
      previousTitleLabel.textAlignment = .center
      previousTitleLabel.adjustsFontForContentSizeCategory = true
      previousStack.addArrangedSubview(previousTitleLabel)

      previousDetailLabel.numberOfLines = 1
      previousDetailLabel.textAlignment = .center
      previousDetailLabel.adjustsFontForContentSizeCategory = true
      previousStack.addArrangedSubview(previousDetailLabel)

      nextContainer.translatesAutoresizingMaskIntoConstraints = false
      nextStack.translatesAutoresizingMaskIntoConstraints = false
      nextStack.axis = .vertical
      nextStack.alignment = .center
      nextStack.spacing = 8
      nextContainer.addSubview(nextStack)

      nextBadgeLabel.numberOfLines = 1
      nextBadgeLabel.textAlignment = .center
      nextBadgeLabel.adjustsFontForContentSizeCategory = true
      nextStack.addArrangedSubview(nextBadgeLabel)

      addChild(nextCoverViewController)
      nextCoverViewController.view.translatesAutoresizingMaskIntoConstraints = false
      nextStack.addArrangedSubview(nextCoverViewController.view)
      nextCoverViewController.didMove(toParent: self)

      nextMetadataStack.axis = .vertical
      nextMetadataStack.alignment = .center
      nextMetadataStack.spacing = 4
      nextStack.addArrangedSubview(nextMetadataStack)

      nextTitleLabel.numberOfLines = 2
      nextTitleLabel.textAlignment = .center
      nextTitleLabel.adjustsFontForContentSizeCategory = true
      nextMetadataStack.addArrangedSubview(nextTitleLabel)

      nextDetailLabel.numberOfLines = 1
      nextDetailLabel.textAlignment = .center
      nextDetailLabel.adjustsFontForContentSizeCategory = true
      nextMetadataStack.addArrangedSubview(nextDetailLabel)

      caughtUpStack.axis = .horizontal
      caughtUpStack.alignment = .center
      caughtUpStack.spacing = 8
      nextStack.addArrangedSubview(caughtUpStack)

      caughtUpIconView.image = UIImage(systemName: "checkmark.circle.fill")
      caughtUpIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
      caughtUpStack.addArrangedSubview(caughtUpIconView)

      caughtUpLabel.numberOfLines = 1
      caughtUpLabel.textAlignment = .center
      caughtUpLabel.adjustsFontForContentSizeCategory = true
      caughtUpStack.addArrangedSubview(caughtUpLabel)

      horizontalDividerStack.axis = .horizontal
      horizontalDividerStack.alignment = .center
      horizontalDividerStack.spacing = 10

      leadingDivider.translatesAutoresizingMaskIntoConstraints = false
      leadingDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true
      leadingDivider.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
      horizontalDividerStack.addArrangedSubview(leadingDivider)

      dividerTitleLabel.numberOfLines = 1
      dividerTitleLabel.textAlignment = .center
      dividerTitleLabel.adjustsFontForContentSizeCategory = true
      horizontalDividerStack.addArrangedSubview(dividerTitleLabel)

      trailingDivider.translatesAutoresizingMaskIntoConstraints = false
      trailingDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true
      trailingDivider.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
      horizontalDividerStack.addArrangedSubview(trailingDivider)

      verticalDivider.translatesAutoresizingMaskIntoConstraints = false
      verticalDivider.widthAnchor.constraint(equalToConstant: 1).isActive = true
      verticalDivider.heightAnchor.constraint(equalToConstant: 220).isActive = true

      buttonStack.axis = .horizontal
      buttonStack.alignment = .center
      buttonStack.spacing = 16
      contentStack.addArrangedSubview(buttonStack)

      closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
      buttonStack.addArrangedSubview(closeButton)

      NSLayoutConstraint.activate([
        contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
        contentStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
        contentStack.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
        contentStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
        contentStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        contentStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        contentStack.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -80),

        previousStack.leadingAnchor.constraint(equalTo: previousContainer.leadingAnchor),
        previousStack.trailingAnchor.constraint(equalTo: previousContainer.trailingAnchor),
        previousStack.topAnchor.constraint(equalTo: previousContainer.topAnchor),
        previousStack.bottomAnchor.constraint(equalTo: previousContainer.bottomAnchor),

        nextStack.leadingAnchor.constraint(equalTo: nextContainer.leadingAnchor),
        nextStack.trailingAnchor.constraint(equalTo: nextContainer.trailingAnchor),
        nextStack.topAnchor.constraint(equalTo: nextContainer.topAnchor),
        nextStack.bottomAnchor.constraint(equalTo: nextContainer.bottomAnchor),

        previousCoverViewController.view.widthAnchor.constraint(equalToConstant: 120),
        previousCoverViewController.view.heightAnchor.constraint(equalToConstant: 160),
        nextCoverViewController.view.widthAnchor.constraint(equalToConstant: 120),
        nextCoverViewController.view.heightAnchor.constraint(equalToConstant: 160),
      ])
    }

    private func applyConfiguration() {
      let textColor = contentColor
      let relationTitle = readListContext?.name ?? previousBook?.seriesTitle ?? nextBook?.seriesTitle ?? ""

      view.backgroundColor = UIColor(renderConfig.readerBackground.color)

      relationHeaderLabel.text = relationTitle
      dividerTitleLabel.text = relationTitle
      dividerTitleLabel.isHidden = relationTitle.isEmpty

      relationHeaderLabel.font = preferredFont(textStyle: .headline, design: .rounded, weight: .semibold)
      previousBadgeLabel.font = preferredFont(textStyle: .caption1, weight: .semibold)
      previousTitleLabel.font = preferredFont(textStyle: .title3, design: .serif, weight: .bold)
      previousDetailLabel.font = .preferredFont(forTextStyle: .caption1)
      nextBadgeLabel.font = preferredFont(textStyle: .caption1, weight: .semibold)
      nextTitleLabel.font = preferredFont(textStyle: .title3, design: .serif, weight: .bold)
      nextDetailLabel.font = .preferredFont(forTextStyle: .caption1)
      caughtUpLabel.font = .preferredFont(forTextStyle: .headline)
      dividerTitleLabel.font = .preferredFont(forTextStyle: .caption1)

      relationHeaderLabel.textColor = textColor.withAlphaComponent(0.85)
      previousBadgeLabel.textColor = textColor.withAlphaComponent(0.55)
      previousTitleLabel.textColor = textColor
      previousDetailLabel.textColor = textColor.withAlphaComponent(0.6)
      nextBadgeLabel.textColor = textColor.withAlphaComponent(0.55)
      nextTitleLabel.textColor = textColor
      nextDetailLabel.textColor = textColor.withAlphaComponent(0.6)
      caughtUpIconView.tintColor = textColor
      caughtUpLabel.textColor = textColor
      dividerTitleLabel.textColor = textColor.withAlphaComponent(0.8)
      leadingDivider.backgroundColor = textColor.withAlphaComponent(0.3)
      trailingDivider.backgroundColor = textColor.withAlphaComponent(0.3)
      verticalDivider.backgroundColor = textColor.withAlphaComponent(0.3)

      previousBadgeLabel.text = String(localized: "reader.previousBook").uppercased()
      nextBadgeLabel.text = String(localized: "reader.nextBook").uppercased()

      if let previousBook {
        previousContainer.isHidden = false
        previousCoverViewController.configure(bookID: previousBook.id)
        previousTitleLabel.text = previousBook.readerChapterTitle
        previousDetailLabel.text = previousBook.readerChapterDetail
      } else {
        previousContainer.isHidden = true
        previousCoverViewController.configure(bookID: nil)
        previousTitleLabel.text = nil
        previousDetailLabel.text = nil
      }

      if let nextBook {
        nextBadgeLabel.isHidden = false
        nextMetadataStack.isHidden = false
        caughtUpStack.isHidden = true
        nextCoverViewController.view.isHidden = false
        nextCoverViewController.configure(bookID: nextBook.id)
        nextTitleLabel.text = nextBook.readerChapterTitle
        nextDetailLabel.text = nextBook.readerChapterDetail
      } else {
        nextBadgeLabel.isHidden = true
        nextMetadataStack.isHidden = true
        caughtUpStack.isHidden = false
        caughtUpLabel.text = String(localized: "You're all caught up!")
        nextCoverViewController.view.isHidden = true
        nextCoverViewController.configure(bookID: nil)
        nextTitleLabel.text = nil
        nextDetailLabel.text = nil
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
      closeButton.isHidden = nextBook != nil

      applyLayoutModeIfNeeded(force: true)
    }

    private func applyLayoutModeIfNeeded(force: Bool = false) {
      guard view.bounds.width > 0, view.bounds.height > 0 else { return }
      let isPortrait = view.bounds.height >= view.bounds.width
      if !force, lastIsPortrait == isPortrait { return }
      lastIsPortrait = isPortrait

      let relationTitle = readListContext?.name ?? previousBook?.seriesTitle ?? nextBook?.seriesTitle ?? ""
      let isForwardOnLeadingSide = readingDirection == .rtl

      if isPortrait {
        sectionsStack.axis = .vertical
        relationHeaderLabel.isHidden = true
        previousStack.alignment = .center
        nextStack.alignment = .center
        previousTitleLabel.textAlignment = .center
        previousDetailLabel.textAlignment = .center
        nextTitleLabel.textAlignment = .center
        nextDetailLabel.textAlignment = .center
        caughtUpLabel.textAlignment = .center
        previousCoverViewController.view.isHidden = true
        setArrangedSubviews(
          of: sectionsStack,
          with: [
            previousContainer.isHidden ? nil : previousContainer,
            horizontalDividerStack,
            nextContainer,
          ]
        )
      } else {
        sectionsStack.axis = .horizontal
        relationHeaderLabel.isHidden = relationTitle.isEmpty
        previousStack.alignment = .center
        nextStack.alignment = .center
        previousTitleLabel.textAlignment = .center
        previousDetailLabel.textAlignment = .center
        nextTitleLabel.textAlignment = .center
        nextDetailLabel.textAlignment = .center
        caughtUpLabel.textAlignment = .center
        previousCoverViewController.view.isHidden = previousBook == nil

        if isForwardOnLeadingSide {
          setArrangedSubviews(
            of: sectionsStack,
            with: [
              nextContainer,
              verticalDivider,
              previousContainer.isHidden ? nil : previousContainer,
            ]
          )
        } else {
          setArrangedSubviews(
            of: sectionsStack,
            with: [
              previousContainer.isHidden ? nil : previousContainer,
              verticalDivider,
              nextContainer,
            ]
          )
        }
      }

      updateSectionsEqualWidthConstraint()
    }

    private func setArrangedSubviews(of stack: UIStackView, with views: [UIView?]) {
      let filteredViews = views.compactMap { $0 }
      if stack.arrangedSubviews.elementsEqual(filteredViews, by: { $0 === $1 }) {
        return
      }

      sectionsEqualWidthConstraint?.isActive = false
      for subview in stack.arrangedSubviews {
        stack.removeArrangedSubview(subview)
        subview.removeFromSuperview()
      }

      for view in filteredViews {
        stack.addArrangedSubview(view)
      }
    }

    private func updateSectionsEqualWidthConstraint() {
      guard previousContainer.superview != nil, previousContainer.superview === nextContainer.superview else {
        sectionsEqualWidthConstraint?.isActive = false
        return
      }

      if sectionsEqualWidthConstraint == nil {
        sectionsEqualWidthConstraint = previousContainer.widthAnchor.constraint(equalTo: nextContainer.widthAnchor)
        sectionsEqualWidthConstraint?.priority = .defaultHigh
      }
      sectionsEqualWidthConstraint?.isActive = true
    }

    private func borderedButtonConfiguration() -> UIButton.Configuration {
      if #available(iOS 26.0, *) {
        return .glass()
      }
      return .bordered()
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

    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
      let location = gesture.location(in: view)
      guard view.bounds.width > 0, view.bounds.height > 0 else { return }

      let normalizedX = location.x / view.bounds.width
      let normalizedY = location.y / view.bounds.height
      let action = TapZoneHelper.action(
        normalizedX: normalizedX,
        normalizedY: normalizedY,
        tapZoneMode: renderConfig.tapZoneMode,
        readingDirection: readingDirection,
        zoneThreshold: renderConfig.tapZoneSize.value
      )

      switch action {
      case .previous:
        onPreviousPage?()
      case .next:
        onNextPage?()
      case .toggleControls:
        onToggleControls?()
      }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
      if let touchedView = touch.view, touchedView is UIControl {
        return false
      }
      return true
    }

  }
#endif
