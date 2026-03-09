#if os(iOS) || os(tvOS)
  import SwiftUI
  import UIKit

  final class NativePagedEndCell: UICollectionViewCell {
    private var previousBook: Book?
    private var nextBook: Book?
    private var readListContext: ReaderReadListContext?
    private var readingDirection: ReadingDirection = .ltr
    private var readerBackground: ReaderBackground = .system
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
    private let closeButton = UIButton(type: .system)

    private var contentLeadingConstraint: NSLayoutConstraint?
    private var contentTrailingConstraint: NSLayoutConstraint?
    private var contentTopConstraint: NSLayoutConstraint?
    private var contentBottomConstraint: NSLayoutConstraint?
    private var previousCoverWidthConstraint: NSLayoutConstraint?
    private var previousCoverHeightConstraint: NSLayoutConstraint?
    private var nextCoverWidthConstraint: NSLayoutConstraint?
    private var nextCoverHeightConstraint: NSLayoutConstraint?
    private var verticalDividerHeightConstraint: NSLayoutConstraint?
    private var sectionsEqualWidthConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
      super.init(frame: frame)
      setupUI()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
      super.prepareForReuse()
      previousCoverView.configure(bookID: nil)
      nextCoverView.configure(bookID: nil)
      lastIsPortrait = nil
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
      readerBackground: ReaderBackground,
      onDismiss: (() -> Void)?
    ) {
      self.previousBook = previousBook
      self.nextBook = nextBook
      self.readListContext = readListContext
      self.readingDirection = readingDirection
      self.readerBackground = readerBackground
      self.onDismiss = onDismiss

      applyAppearance()
      applyContent()
      setNeedsLayout()
    }

    private func setupUI() {
      backgroundColor = .clear
      contentView.backgroundColor = UIColor(readerBackground.color)

      contentStack.translatesAutoresizingMaskIntoConstraints = false
      contentStack.axis = .vertical
      contentStack.alignment = .fill
      contentStack.spacing = 20
      contentStack.isLayoutMarginsRelativeArrangement = true
      contentStack.layoutMargins = UIEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
      contentView.addSubview(contentStack)

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
      previousStack.spacing = 8
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

      nextTitleLabel.numberOfLines = 2
      nextTitleLabel.textAlignment = .center
      nextTitleLabel.adjustsFontForContentSizeCategory = true
      nextStack.addArrangedSubview(nextTitleLabel)

      nextDetailLabel.numberOfLines = 1
      nextDetailLabel.textAlignment = .center
      nextDetailLabel.adjustsFontForContentSizeCategory = true
      nextStack.addArrangedSubview(nextDetailLabel)

      caughtUpStack.axis = .horizontal
      caughtUpStack.alignment = .center
      caughtUpStack.spacing = 8
      nextStack.addArrangedSubview(caughtUpStack)

      caughtUpIconView.image = UIImage(systemName: "checkmark.circle.fill")
      caughtUpStack.addArrangedSubview(caughtUpIconView)

      caughtUpLabel.numberOfLines = 2
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

      closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
      contentStack.addArrangedSubview(closeButton)

      let contentLeading = contentStack.leadingAnchor.constraint(
        greaterThanOrEqualTo: contentView.leadingAnchor,
        constant: 40
      )
      let contentTrailing = contentStack.trailingAnchor.constraint(
        lessThanOrEqualTo: contentView.trailingAnchor,
        constant: -40
      )
      let contentTop = contentStack.topAnchor.constraint(
        greaterThanOrEqualTo: contentView.topAnchor,
        constant: 40
      )
      let contentBottom = contentStack.bottomAnchor.constraint(
        lessThanOrEqualTo: contentView.bottomAnchor,
        constant: -40
      )
      contentLeadingConstraint = contentLeading
      contentTrailingConstraint = contentTrailing
      contentTopConstraint = contentTop
      contentBottomConstraint = contentBottom

      previousCoverWidthConstraint = previousCoverView.widthAnchor.constraint(equalToConstant: 120)
      previousCoverHeightConstraint = previousCoverView.heightAnchor.constraint(equalToConstant: 160)
      nextCoverWidthConstraint = nextCoverView.widthAnchor.constraint(equalToConstant: 120)
      nextCoverHeightConstraint = nextCoverView.heightAnchor.constraint(equalToConstant: 160)

      NSLayoutConstraint.activate([
        contentLeading,
        contentTrailing,
        contentTop,
        contentBottom,
        contentStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        contentStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

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

      previousBadgeLabel.text = String(localized: "reader.previousBook").uppercased()
      nextBadgeLabel.text = String(localized: "reader.nextBook").uppercased()
      caughtUpLabel.text = String(localized: "You're all caught up!")
    }

    private func applyAppearance() {
      let backgroundColor = UIColor(readerBackground.color)
      let textColor = UIColor(readerBackground.contentColor)

      contentView.backgroundColor = backgroundColor
      relationHeaderLabel.textColor = textColor.withAlphaComponent(0.85)
      dividerTitleLabel.textColor = textColor.withAlphaComponent(0.8)
      previousBadgeLabel.textColor = textColor.withAlphaComponent(0.55)
      previousTitleLabel.textColor = textColor
      previousDetailLabel.textColor = textColor.withAlphaComponent(0.6)
      nextBadgeLabel.textColor = textColor.withAlphaComponent(0.55)
      nextTitleLabel.textColor = textColor
      nextDetailLabel.textColor = textColor.withAlphaComponent(0.6)
      caughtUpIconView.tintColor = textColor
      caughtUpLabel.textColor = textColor
      leadingDivider.backgroundColor = textColor.withAlphaComponent(0.3)
      trailingDivider.backgroundColor = textColor.withAlphaComponent(0.3)
      verticalDivider.backgroundColor = textColor.withAlphaComponent(0.3)

      previousCoverView.useLightShadow = shouldUseLightCoverShadow
      nextCoverView.useLightShadow = shouldUseLightCoverShadow
      previousCoverView.imageBlendTintColor = coverBlendTintColor
      nextCoverView.imageBlendTintColor = coverBlendTintColor

      relationHeaderLabel.font = .preferredFont(forTextStyle: .headline)
      previousBadgeLabel.font = .preferredFont(forTextStyle: .caption1)
      previousTitleLabel.font = .preferredFont(forTextStyle: .title3)
      previousDetailLabel.font = .preferredFont(forTextStyle: .caption1)
      nextBadgeLabel.font = .preferredFont(forTextStyle: .caption1)
      nextTitleLabel.font = .preferredFont(forTextStyle: .title3)
      nextDetailLabel.font = .preferredFont(forTextStyle: .caption1)
      caughtUpLabel.font = .preferredFont(forTextStyle: .headline)
      dividerTitleLabel.font = .preferredFont(forTextStyle: .caption1)

      var configuration = UIButton.Configuration.bordered()
      configuration.image = UIImage(systemName: "xmark")
      configuration.imagePlacement = .leading
      configuration.imagePadding = 8
      configuration.title = String(localized: "Close")
      configuration.cornerStyle = .capsule
      closeButton.configuration = configuration
      closeButton.tintColor = textColor
    }

    private func applyContent() {
      let presentation = NativeEndPagePresentation.make(
        previousBook: previousBook,
        nextBook: nextBook,
        readListContext: readListContext
      )

      relationHeaderLabel.text = presentation.relationTitle
      dividerTitleLabel.text = presentation.relationTitle
      dividerTitleLabel.isHidden = presentation.relationTitle.isEmpty
      previousBadgeLabel.text = presentation.previous.badgeText
      nextBadgeLabel.text = presentation.next.badgeText

      if presentation.previous.isVisible {
        previousContainer.isHidden = false
        previousCoverView.isHidden = !presentation.previous.showsCover
        previousTitleLabel.text = presentation.previous.title
        previousDetailLabel.text = presentation.previous.detail
        previousCoverView.configure(bookID: presentation.previous.bookID)
      } else {
        previousContainer.isHidden = true
        previousCoverView.isHidden = true
        previousTitleLabel.text = nil
        previousDetailLabel.text = nil
        previousCoverView.configure(bookID: nil)
      }

      if presentation.next.isVisible {
        nextContainer.isHidden = false
        nextBadgeLabel.isHidden = presentation.next.badgeText == nil
        nextCoverView.isHidden = !presentation.next.showsCover
        nextTitleLabel.isHidden = !presentation.next.showsMetadata
        nextDetailLabel.isHidden = !presentation.next.showsMetadata
        caughtUpStack.isHidden = !presentation.next.showsCaughtUp
        nextTitleLabel.text = presentation.next.title
        nextDetailLabel.text = presentation.next.detail
        nextCoverView.configure(bookID: presentation.next.bookID)
      } else {
        nextContainer.isHidden = true
        nextBadgeLabel.isHidden = true
        nextCoverView.isHidden = true
        nextTitleLabel.isHidden = true
        nextDetailLabel.isHidden = true
        caughtUpStack.isHidden = false
        nextTitleLabel.text = nil
        nextDetailLabel.text = nil
        nextCoverView.configure(bookID: nil)
      }

      closeButton.isHidden = !presentation.showsCloseButton
    }

    private func applyLayoutModeIfNeeded(force: Bool = false) {
      guard bounds.width > 0, bounds.height > 0 else { return }

      let isPortrait = bounds.height >= bounds.width
      if !force, lastIsPortrait == isPortrait { return }
      lastIsPortrait = isPortrait

      let presentation = NativeEndPagePresentation.make(
        previousBook: previousBook,
        nextBook: nextBook,
        readListContext: readListContext
      )

      switch presentation.layoutMode(for: bounds.size, readingDirection: readingDirection) {
      case .singlePrevious:
        sectionsStack.axis = .vertical
        relationHeaderLabel.isHidden = true
        setArrangedSubviews(of: sectionsStack, with: [previousContainer])
      case .singleNext:
        sectionsStack.axis = .vertical
        relationHeaderLabel.isHidden = true
        setArrangedSubviews(of: sectionsStack, with: [nextContainer])
      case .stacked:
        sectionsStack.axis = .vertical
        relationHeaderLabel.isHidden = true
        setArrangedSubviews(
          of: sectionsStack,
          with: [previousContainer, horizontalDividerStack, nextContainer]
        )
      case .sideBySide(let nextOnLeadingSide, let showsRelationHeader):
        sectionsStack.axis = .horizontal
        relationHeaderLabel.isHidden = !showsRelationHeader
        if nextOnLeadingSide {
          setArrangedSubviews(
            of: sectionsStack,
            with: [nextContainer, verticalDivider, previousContainer]
          )
        } else {
          setArrangedSubviews(
            of: sectionsStack,
            with: [previousContainer, verticalDivider, nextContainer]
          )
        }
      }

      updateSectionsEqualWidthConstraint()
    }

    private func setArrangedSubviews(of stack: UIStackView, with views: [UIView]) {
      if stack.arrangedSubviews.elementsEqual(views, by: { $0 === $1 }) {
        return
      }

      sectionsEqualWidthConstraint?.isActive = false
      for subview in stack.arrangedSubviews {
        stack.removeArrangedSubview(subview)
        subview.removeFromSuperview()
      }

      for view in views {
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
      sectionsEqualWidthConstraint?.isActive = sectionsStack.axis == .horizontal
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
      let coverWidth = clamped(minDimension * (isPortrait ? 0.28 : 0.22), lower: 96, upper: 190)
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
      previousCoverWidthConstraint?.constant = coverWidth
      previousCoverHeightConstraint?.constant = coverHeight
      nextCoverWidthConstraint?.constant = coverWidth
      nextCoverHeightConstraint?.constant = coverHeight
      verticalDividerHeightConstraint?.constant = dividerHeight
    }

    private var shouldUseLightCoverShadow: Bool {
      switch readerBackground {
      case .black, .gray:
        return true
      case .white, .sepia:
        return false
      case .system:
        return traitCollection.userInterfaceStyle == .dark
      }
    }

    private var coverBlendTintColor: UIColor? {
      readerBackground.appliesImageMultiplyBlend ? UIColor(readerBackground.color) : nil
    }

    private func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
      Swift.min(Swift.max(value, lower), upper)
    }

    @objc private func handleClose() {
      onDismiss?()
    }
  }
#endif
