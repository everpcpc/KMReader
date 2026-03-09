#if os(iOS) || os(tvOS)
  import SwiftUI
  import UIKit

  @MainActor
  final class NativeEndPageContentView: UIView {
    private var previousBook: Book?
    private var nextBook: Book?
    private var readListContext: ReaderReadListContext?
    private var readingDirection: ReadingDirection = .ltr
    private var sectionDisplayMode: NativeEndPagePresentation.SectionDisplayMode = .both
    private var renderConfig = ReaderRenderConfig(
      tapZoneSize: .large,
      tapZoneMode: .auto,
      showPageNumber: true,
      readerBackground: .system,
      enableLiveText: false,
      doubleTapZoomScale: 3.0,
      doubleTapZoomMode: .fast
    )
    private var onDismiss: (() -> Void)?
    private var lastIsPortrait: Bool?

    private let contentStack = UIStackView()
    private let relationHeaderLabel = UILabel()
    private let sectionsStack = UIStackView()

    private let previousContainer = UIView()
    private let previousStack = UIStackView()
    private let previousBadgeLabel = UILabel()
    private let previousCoverView = NativeBookCoverView()
    private let previousTitleLabel = UILabel()
    private let previousDetailLabel = UILabel()

    private let nextContainer = UIView()
    private let nextStack = UIStackView()
    private let nextBadgeLabel = UILabel()
    private let nextCoverView = NativeBookCoverView()
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
    private var contentLeadingConstraint: NSLayoutConstraint?
    private var contentTrailingConstraint: NSLayoutConstraint?
    private var contentTopConstraint: NSLayoutConstraint?
    private var contentBottomConstraint: NSLayoutConstraint?
    private var contentMaxWidthConstraint: NSLayoutConstraint?
    private var previousCoverWidthConstraint: NSLayoutConstraint?
    private var previousCoverHeightConstraint: NSLayoutConstraint?
    private var nextCoverWidthConstraint: NSLayoutConstraint?
    private var nextCoverHeightConstraint: NSLayoutConstraint?
    private var verticalDividerHeightConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
      super.init(frame: frame)
      setupUI()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      applyDynamicMetrics()
      applyLayoutModeIfNeeded()
    }

    func configure(
      previousBook: Book?,
      nextBook: Book?,
      readListContext: ReaderReadListContext?,
      readingDirection: ReadingDirection,
      sectionDisplayMode: NativeEndPagePresentation.SectionDisplayMode = .both,
      renderConfig: ReaderRenderConfig,
      onDismiss: (() -> Void)?
    ) {
      self.previousBook = previousBook
      self.nextBook = nextBook
      self.readListContext = readListContext
      self.readingDirection = readingDirection
      self.sectionDisplayMode = sectionDisplayMode
      self.renderConfig = renderConfig
      self.onDismiss = onDismiss
      applyConfiguration()
    }

    private func setupUI() {
      backgroundColor = UIColor(renderConfig.readerBackground.color)

      contentStack.translatesAutoresizingMaskIntoConstraints = false
      contentStack.axis = .vertical
      contentStack.alignment = .fill
      contentStack.spacing = 20
      contentStack.isLayoutMarginsRelativeArrangement = true
      contentStack.layoutMargins = UIEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
      addSubview(contentStack)

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

      previousCoverView.translatesAutoresizingMaskIntoConstraints = false
      previousStack.addArrangedSubview(previousCoverView)

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

      nextCoverView.translatesAutoresizingMaskIntoConstraints = false
      nextStack.addArrangedSubview(nextCoverView)

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
      verticalDividerHeightConstraint = verticalDivider.heightAnchor.constraint(equalToConstant: 220)
      verticalDividerHeightConstraint?.isActive = true

      buttonStack.axis = .horizontal
      buttonStack.alignment = .center
      buttonStack.spacing = 16
      contentStack.addArrangedSubview(buttonStack)

      closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
      buttonStack.addArrangedSubview(closeButton)

      let contentLeading = contentStack.leadingAnchor.constraint(
        greaterThanOrEqualTo: leadingAnchor,
        constant: 40
      )
      let contentTrailing = contentStack.trailingAnchor.constraint(
        lessThanOrEqualTo: trailingAnchor,
        constant: -40
      )
      let contentTop = contentStack.topAnchor.constraint(
        greaterThanOrEqualTo: safeAreaLayoutGuide.topAnchor,
        constant: 40
      )
      let contentBottom = contentStack.bottomAnchor.constraint(
        lessThanOrEqualTo: safeAreaLayoutGuide.bottomAnchor,
        constant: -40
      )
      let contentMaxWidth = contentStack.widthAnchor.constraint(
        lessThanOrEqualTo: widthAnchor,
        constant: -80
      )
      contentLeadingConstraint = contentLeading
      contentTrailingConstraint = contentTrailing
      contentTopConstraint = contentTop
      contentBottomConstraint = contentBottom
      contentMaxWidthConstraint = contentMaxWidth

      previousCoverWidthConstraint = previousCoverView.widthAnchor.constraint(equalToConstant: 120)
      previousCoverHeightConstraint = previousCoverView.heightAnchor.constraint(equalToConstant: 160)
      nextCoverWidthConstraint = nextCoverView.widthAnchor.constraint(equalToConstant: 120)
      nextCoverHeightConstraint = nextCoverView.heightAnchor.constraint(equalToConstant: 160)

      NSLayoutConstraint.activate([
        contentLeading,
        contentTrailing,
        contentTop,
        contentBottom,
        contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
        contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        contentMaxWidth,

        previousStack.leadingAnchor.constraint(equalTo: previousContainer.leadingAnchor),
        previousStack.trailingAnchor.constraint(equalTo: previousContainer.trailingAnchor),
        previousStack.topAnchor.constraint(equalTo: previousContainer.topAnchor),
        previousStack.bottomAnchor.constraint(equalTo: previousContainer.bottomAnchor),

        nextStack.leadingAnchor.constraint(equalTo: nextContainer.leadingAnchor),
        nextStack.trailingAnchor.constraint(equalTo: nextContainer.trailingAnchor),
        nextStack.topAnchor.constraint(equalTo: nextContainer.topAnchor),
        nextStack.bottomAnchor.constraint(equalTo: nextContainer.bottomAnchor),

        previousCoverWidthConstraint!,
        previousCoverHeightConstraint!,
        nextCoverWidthConstraint!,
        nextCoverHeightConstraint!,
      ])
    }

    private func applyConfiguration() {
      let textColor = contentColor
      let presentation = NativeEndPagePresentation.make(
        previousBook: previousBook,
        nextBook: nextBook,
        readListContext: readListContext,
        sectionDisplayMode: sectionDisplayMode
      )
      let showsBothSections = presentation.previous.isVisible && presentation.next.isVisible
      let visibleRelationTitle = showsBothSections ? presentation.relationTitle : ""

      backgroundColor = UIColor(renderConfig.readerBackground.color)

      relationHeaderLabel.text = visibleRelationTitle
      dividerTitleLabel.text = visibleRelationTitle
      dividerTitleLabel.isHidden = visibleRelationTitle.isEmpty

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
      previousCoverView.useLightShadow = shouldUseLightCoverShadow
      nextCoverView.useLightShadow = shouldUseLightCoverShadow
      previousCoverView.imageBlendTintColor = coverBlendTintColor
      nextCoverView.imageBlendTintColor = coverBlendTintColor

      previousBadgeLabel.text = String(localized: "reader.previousBook").uppercased()
      nextBadgeLabel.text = presentation.next.badgeText

      if presentation.previous.isVisible {
        previousContainer.isHidden = false
        previousBadgeLabel.text = presentation.previous.badgeText
        previousCoverView.configure(bookID: presentation.previous.bookID)
        previousTitleLabel.text = presentation.previous.title
        previousDetailLabel.text = presentation.previous.detail
      } else {
        previousContainer.isHidden = true
        previousBadgeLabel.text = nil
        previousCoverView.configure(bookID: nil)
        previousTitleLabel.text = nil
        previousDetailLabel.text = nil
      }

      if presentation.next.isVisible {
        nextContainer.isHidden = false
        nextBadgeLabel.isHidden = presentation.next.badgeText == nil
        nextMetadataStack.isHidden = !presentation.next.showsMetadata
        caughtUpStack.isHidden = !presentation.next.showsCaughtUp
        caughtUpLabel.text = presentation.next.showsCaughtUp ? String(localized: "You're all caught up!") : nil
        nextCoverView.isHidden = !presentation.next.showsCover
        nextCoverView.configure(bookID: presentation.next.bookID)
        nextTitleLabel.text = presentation.next.title
        nextDetailLabel.text = presentation.next.detail
      } else {
        nextContainer.isHidden = true
        nextBadgeLabel.isHidden = true
        nextMetadataStack.isHidden = true
        caughtUpStack.isHidden = true
        caughtUpLabel.text = nil
        nextCoverView.isHidden = true
        nextCoverView.configure(bookID: nil)
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
      closeButton.isHidden = !presentation.showsCloseButton

      applyDynamicMetrics()
      applyLayoutModeIfNeeded(force: true)
    }

    private func applyLayoutModeIfNeeded(force: Bool = false) {
      guard bounds.width > 0, bounds.height > 0 else { return }
      let isPortrait = bounds.height >= bounds.width
      if !force, lastIsPortrait == isPortrait { return }
      lastIsPortrait = isPortrait

      let presentation = NativeEndPagePresentation.make(
        previousBook: previousBook,
        nextBook: nextBook,
        readListContext: readListContext,
        sectionDisplayMode: sectionDisplayMode
      )

      previousStack.alignment = .center
      nextStack.alignment = .center
      previousTitleLabel.textAlignment = .center
      previousDetailLabel.textAlignment = .center
      nextTitleLabel.textAlignment = .center
      nextDetailLabel.textAlignment = .center
      caughtUpLabel.textAlignment = .center

      switch presentation.layoutMode(for: bounds.size, readingDirection: readingDirection) {
      case .singlePrevious:
        sectionsStack.axis = .vertical
        relationHeaderLabel.isHidden = true
        previousCoverView.isHidden = previousBook == nil
        setArrangedSubviews(
          of: sectionsStack,
          with: [
            previousContainer.isHidden ? nil : previousContainer
          ]
        )
      case .singleNext:
        sectionsStack.axis = .vertical
        relationHeaderLabel.isHidden = true
        previousCoverView.isHidden = previousBook == nil
        setArrangedSubviews(
          of: sectionsStack,
          with: [
            nextContainer.isHidden ? nil : nextContainer
          ]
        )
      case .stacked:
        sectionsStack.axis = .vertical
        relationHeaderLabel.isHidden = true
        previousCoverView.isHidden = true
        setArrangedSubviews(
          of: sectionsStack,
          with: [
            previousContainer.isHidden ? nil : previousContainer,
            horizontalDividerStack,
            nextContainer,
          ]
        )
      case .sideBySide(let nextOnLeadingSide, let showsRelationHeader):
        sectionsStack.axis = .horizontal
        relationHeaderLabel.isHidden = !showsRelationHeader
        previousCoverView.isHidden = previousBook == nil

        if nextOnLeadingSide {
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

    private func applyDynamicMetrics() {
      guard bounds.width > 0, bounds.height > 0 else { return }

      let isPortrait = bounds.height >= bounds.width
      let minDimension = min(bounds.width, bounds.height)
      let maxDimension = max(bounds.width, bounds.height)
      let outerPadding = clamped(minDimension * 0.08, lower: 20, upper: 56)
      let innerPadding = clamped(minDimension * 0.045, lower: 16, upper: 32)
      let stackSpacing = clamped(minDimension * 0.034, lower: 12, upper: 22)
      let portraitSectionSpacing = stackSpacing + clamped(stackSpacing * 0.5, lower: 6, upper: 12)
      let coverWidth = clamped(minDimension * 0.24, lower: 96, upper: 190)
      let coverHeight = coverWidth / CoverAspectRatio.widthToHeight
      let dividerHeight = clamped(maxDimension * 0.32, lower: 140, upper: 320)

      contentStack.spacing = stackSpacing
      sectionsStack.spacing = isPortrait ? portraitSectionSpacing : stackSpacing
      contentStack.layoutMargins = UIEdgeInsets(
        top: innerPadding,
        left: innerPadding,
        bottom: innerPadding,
        right: innerPadding
      )

      contentLeadingConstraint?.constant = outerPadding
      contentTrailingConstraint?.constant = -outerPadding
      contentTopConstraint?.constant = outerPadding
      contentBottomConstraint?.constant = -outerPadding
      contentMaxWidthConstraint?.constant = -outerPadding * 2
      previousCoverWidthConstraint?.constant = coverWidth
      previousCoverHeightConstraint?.constant = coverHeight
      nextCoverWidthConstraint?.constant = coverWidth
      nextCoverHeightConstraint?.constant = coverHeight
      verticalDividerHeightConstraint?.constant = dividerHeight
    }

    private func borderedButtonConfiguration() -> UIButton.Configuration {
      #if os(iOS)
        if #available(iOS 26.0, *) {
          return .glass()
        }
      #endif
      return .bordered()
    }

    private var buttonSymbolConfiguration: UIImage.SymbolConfiguration {
      UIImage.SymbolConfiguration(
        textStyle: .subheadline,
        scale: .small
      )
    }

    private var contentColor: UIColor {
      switch renderConfig.readerBackground {
      case .black, .gray:
        return .white
      case .white:
        return .black
      case .sepia:
        return UIColor(renderConfig.readerBackground.contentColor)
      case .system:
        return .label
      }
    }

    private var shouldUseLightCoverShadow: Bool {
      switch renderConfig.readerBackground {
      case .black, .gray:
        return true
      case .white, .sepia:
        return false
      case .system:
        return traitCollection.userInterfaceStyle == .dark
      }
    }

    private var coverBlendTintColor: UIColor? {
      renderConfig.readerBackground.appliesImageMultiplyBlend
        ? UIColor(renderConfig.readerBackground.color)
        : nil
    }

    private func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
      Swift.min(Swift.max(value, lower), upper)
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
  }
#endif
