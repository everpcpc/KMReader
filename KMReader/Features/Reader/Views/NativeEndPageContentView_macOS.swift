#if os(macOS)
  import AppKit
  import SwiftUI

  @MainActor
  final class NativeEndPageContentView: NSView {
    private var previousBook: Book?
    private var nextBook: Book?
    private var readListContext: ReaderReadListContext?
    private var readingDirection: ReadingDirection = .ltr
    private var sectionDisplayMode: NativeEndPagePresentation.SectionDisplayMode = .both
    private var renderConfig = ReaderRenderConfig(
      tapZoneSize: .large,
      tapZoneMode: .auto,
      showPageNumber: true,
      showPageShadow: true,
      readerBackground: .system,
      enableLiveText: false,
      enableImageContextMenu: false,
      supportsPageIsolationActions: false,
      doubleTapZoomScale: 3.0,
      doubleTapZoomMode: .fast
    )
    private var onDismiss: (() -> Void)?
    private var lastIsPortrait: Bool?

    private let contentStack = NSStackView()
    private let sectionsStack = NSStackView()

    private let previousContainer = NSView()
    private let previousStack = NSStackView()
    private let previousBadgeLabel = NSTextField(labelWithString: "")
    private let previousCoverView = NativeBookCoverView()
    private let previousMetadataStack = NSStackView()
    private let previousTitleLabel = NSTextField(labelWithString: "")
    private let previousDetailLabel = NSTextField(labelWithString: "")

    private let nextContainer = NSView()
    private let nextStack = NSStackView()
    private let nextBadgeLabel = NSTextField(labelWithString: "")
    private let nextCoverView = NativeBookCoverView()
    private let nextMetadataStack = NSStackView()
    private let nextTitleLabel = NSTextField(labelWithString: "")
    private let nextDetailLabel = NSTextField(labelWithString: "")
    private let caughtUpStack = NSStackView()
    private let caughtUpIconView = NSImageView()
    private let caughtUpLabel = NSTextField(labelWithString: "")

    private let horizontalDividerStack = NSStackView()
    private let leadingDivider = NSView()
    private let dividerTitleLabel = NSTextField(labelWithString: "")
    private let trailingDivider = NSView()
    private let verticalDivider = NSView()
    private let closeButton = NSButton()

    private var contentLeadingConstraint: NSLayoutConstraint?
    private var contentTrailingConstraint: NSLayoutConstraint?
    private var contentTopConstraint: NSLayoutConstraint?
    private var contentBottomConstraint: NSLayoutConstraint?
    private var contentMaxWidthConstraint: NSLayoutConstraint?
    private var horizontalDividerWidthConstraint: NSLayoutConstraint?
    private var previousCoverWidthConstraint: NSLayoutConstraint?
    private var previousCoverHeightConstraint: NSLayoutConstraint?
    private var nextCoverWidthConstraint: NSLayoutConstraint?
    private var nextCoverHeightConstraint: NSLayoutConstraint?
    private var verticalDividerHeightConstraint: NSLayoutConstraint?
    private var sectionsEqualWidthConstraint: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
      super.init(frame: frameRect)
      setupUI()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
      super.layout()
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
      needsLayout = true
    }

    private func setupUI() {
      wantsLayer = true
      layer?.backgroundColor = NSColor(renderConfig.readerBackground.color).cgColor

      contentStack.translatesAutoresizingMaskIntoConstraints = false
      contentStack.orientation = .vertical
      contentStack.alignment = .centerX
      contentStack.spacing = 20
      addSubview(contentStack)

      sectionsStack.orientation = .vertical
      sectionsStack.alignment = .centerX
      sectionsStack.spacing = 20
      contentStack.addArrangedSubview(sectionsStack)

      previousContainer.translatesAutoresizingMaskIntoConstraints = false
      previousStack.translatesAutoresizingMaskIntoConstraints = false
      previousStack.orientation = .vertical
      previousStack.alignment = .centerX
      previousStack.spacing = 8
      previousContainer.addSubview(previousStack)

      previousBadgeLabel.alignment = .center
      previousBadgeLabel.maximumNumberOfLines = 1
      previousStack.addArrangedSubview(previousBadgeLabel)

      previousCoverView.translatesAutoresizingMaskIntoConstraints = false
      previousStack.addArrangedSubview(previousCoverView)

      previousMetadataStack.orientation = .vertical
      previousMetadataStack.alignment = .centerX
      previousMetadataStack.spacing = 4
      previousStack.addArrangedSubview(previousMetadataStack)

      previousTitleLabel.alignment = .center
      previousTitleLabel.maximumNumberOfLines = 2
      previousTitleLabel.lineBreakMode = .byTruncatingTail
      previousMetadataStack.addArrangedSubview(previousTitleLabel)

      previousDetailLabel.alignment = .center
      previousDetailLabel.maximumNumberOfLines = 1
      previousDetailLabel.lineBreakMode = .byTruncatingTail
      previousMetadataStack.addArrangedSubview(previousDetailLabel)

      nextContainer.translatesAutoresizingMaskIntoConstraints = false
      nextStack.translatesAutoresizingMaskIntoConstraints = false
      nextStack.orientation = .vertical
      nextStack.alignment = .centerX
      nextStack.spacing = 8
      nextContainer.addSubview(nextStack)

      nextBadgeLabel.alignment = .center
      nextBadgeLabel.maximumNumberOfLines = 1
      nextStack.addArrangedSubview(nextBadgeLabel)

      nextCoverView.translatesAutoresizingMaskIntoConstraints = false
      nextStack.addArrangedSubview(nextCoverView)

      nextMetadataStack.orientation = .vertical
      nextMetadataStack.alignment = .centerX
      nextMetadataStack.spacing = 4
      nextStack.addArrangedSubview(nextMetadataStack)

      nextTitleLabel.alignment = .center
      nextTitleLabel.maximumNumberOfLines = 2
      nextTitleLabel.lineBreakMode = .byTruncatingTail
      nextMetadataStack.addArrangedSubview(nextTitleLabel)

      nextDetailLabel.alignment = .center
      nextDetailLabel.maximumNumberOfLines = 1
      nextDetailLabel.lineBreakMode = .byTruncatingTail
      nextMetadataStack.addArrangedSubview(nextDetailLabel)

      caughtUpStack.orientation = .horizontal
      caughtUpStack.alignment = .centerY
      caughtUpStack.spacing = 8
      nextStack.addArrangedSubview(caughtUpStack)

      caughtUpIconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
      caughtUpStack.addArrangedSubview(caughtUpIconView)

      caughtUpLabel.alignment = .center
      caughtUpLabel.maximumNumberOfLines = 2
      caughtUpStack.addArrangedSubview(caughtUpLabel)

      horizontalDividerStack.orientation = .horizontal
      horizontalDividerStack.alignment = .centerY
      horizontalDividerStack.spacing = 10
      horizontalDividerStack.setContentCompressionResistancePriority(.required, for: .vertical)
      horizontalDividerStack.setContentHuggingPriority(.required, for: .vertical)
      horizontalDividerStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 18).isActive = true
      horizontalDividerWidthConstraint = horizontalDividerStack.widthAnchor.constraint(equalToConstant: 320)
      horizontalDividerWidthConstraint?.isActive = true

      leadingDivider.wantsLayer = true
      leadingDivider.translatesAutoresizingMaskIntoConstraints = false
      leadingDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true
      leadingDivider.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
      horizontalDividerStack.addArrangedSubview(leadingDivider)

      dividerTitleLabel.alignment = .center
      dividerTitleLabel.maximumNumberOfLines = 1
      dividerTitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
      dividerTitleLabel.setContentHuggingPriority(.required, for: .vertical)
      horizontalDividerStack.addArrangedSubview(dividerTitleLabel)

      trailingDivider.wantsLayer = true
      trailingDivider.translatesAutoresizingMaskIntoConstraints = false
      trailingDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true
      trailingDivider.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
      horizontalDividerStack.addArrangedSubview(trailingDivider)
      leadingDivider.widthAnchor.constraint(equalTo: trailingDivider.widthAnchor).isActive = true

      verticalDivider.wantsLayer = true
      verticalDivider.translatesAutoresizingMaskIntoConstraints = false
      verticalDivider.widthAnchor.constraint(equalToConstant: 1).isActive = true
      verticalDividerHeightConstraint = verticalDivider.heightAnchor.constraint(equalToConstant: 220)
      verticalDividerHeightConstraint?.isActive = true

      closeButton.bezelStyle = .rounded
      closeButton.target = self
      closeButton.action = #selector(handleClose)
      contentStack.addArrangedSubview(closeButton)

      let contentLeading = contentStack.leadingAnchor.constraint(
        greaterThanOrEqualTo: leadingAnchor,
        constant: 40
      )
      let contentTrailing = contentStack.trailingAnchor.constraint(
        lessThanOrEqualTo: trailingAnchor,
        constant: -40
      )
      let contentTop = contentStack.topAnchor.constraint(
        greaterThanOrEqualTo: topAnchor,
        constant: 40
      )
      let contentBottom = contentStack.bottomAnchor.constraint(
        lessThanOrEqualTo: bottomAnchor,
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
        previousMetadataStack.widthAnchor.constraint(equalTo: previousStack.widthAnchor),

        nextStack.leadingAnchor.constraint(equalTo: nextContainer.leadingAnchor),
        nextStack.trailingAnchor.constraint(equalTo: nextContainer.trailingAnchor),
        nextStack.topAnchor.constraint(equalTo: nextContainer.topAnchor),
        nextStack.bottomAnchor.constraint(equalTo: nextContainer.bottomAnchor),
        nextMetadataStack.widthAnchor.constraint(equalTo: nextStack.widthAnchor),

        previousCoverWidthConstraint!,
        previousCoverHeightConstraint!,
        nextCoverWidthConstraint!,
        nextCoverHeightConstraint!,
      ])
    }

    private func applyConfiguration() {
      let textColor = NSColor(renderConfig.readerBackground.contentColor)
      let presentation = NativeEndPagePresentation.make(
        previousBook: previousBook,
        nextBook: nextBook,
        readListContext: readListContext,
        sectionDisplayMode: sectionDisplayMode
      )
      let relationTitle = presentation.relationTitle

      layer?.backgroundColor = NSColor(renderConfig.readerBackground.color).cgColor

      dividerTitleLabel.stringValue = relationTitle
      dividerTitleLabel.isHidden = relationTitle.isEmpty

      previousBadgeLabel.font = NSFont.preferredFont(forTextStyle: .caption1)
      previousTitleLabel.font = NSFont.preferredFont(forTextStyle: .title3)
      previousDetailLabel.font = NSFont.preferredFont(forTextStyle: .caption1)
      nextBadgeLabel.font = NSFont.preferredFont(forTextStyle: .caption1)
      nextTitleLabel.font = NSFont.preferredFont(forTextStyle: .title3)
      nextDetailLabel.font = NSFont.preferredFont(forTextStyle: .caption1)
      caughtUpLabel.font = NSFont.preferredFont(forTextStyle: .headline)
      dividerTitleLabel.font = NSFont.preferredFont(forTextStyle: .caption1)

      previousBadgeLabel.textColor = textColor.withAlphaComponent(0.55)
      previousTitleLabel.textColor = textColor
      previousDetailLabel.textColor = textColor.withAlphaComponent(0.6)
      nextBadgeLabel.textColor = textColor.withAlphaComponent(0.55)
      nextTitleLabel.textColor = textColor
      nextDetailLabel.textColor = textColor.withAlphaComponent(0.6)
      caughtUpIconView.contentTintColor = textColor
      caughtUpLabel.textColor = textColor
      dividerTitleLabel.textColor = textColor.withAlphaComponent(0.8)
      leadingDivider.layer?.backgroundColor = textColor.withAlphaComponent(0.3).cgColor
      trailingDivider.layer?.backgroundColor = textColor.withAlphaComponent(0.3).cgColor
      verticalDivider.layer?.backgroundColor = textColor.withAlphaComponent(0.3).cgColor
      previousCoverView.useLightShadow = shouldUseLightCoverShadow
      nextCoverView.useLightShadow = shouldUseLightCoverShadow
      previousCoverView.imageBlendTintColor = coverBlendTintColor
      nextCoverView.imageBlendTintColor = coverBlendTintColor

      previousBadgeLabel.stringValue = String(localized: "reader.previousBook").uppercased()
      nextBadgeLabel.stringValue = presentation.next.badgeText ?? ""

      if presentation.previous.isVisible {
        previousContainer.isHidden = false
        previousCoverView.isHidden = !presentation.previous.showsCover
        previousTitleLabel.stringValue = presentation.previous.title ?? ""
        previousDetailLabel.stringValue = presentation.previous.detail ?? ""
        previousCoverView.configure(bookID: presentation.previous.bookID)
      } else {
        previousContainer.isHidden = true
        previousCoverView.isHidden = true
        previousTitleLabel.stringValue = ""
        previousDetailLabel.stringValue = ""
        previousCoverView.configure(bookID: nil)
      }

      if presentation.next.isVisible {
        nextContainer.isHidden = false
        nextBadgeLabel.isHidden = presentation.next.badgeText == nil
        nextCoverView.isHidden = !presentation.next.showsCover
        nextMetadataStack.isHidden = !presentation.next.showsMetadata
        caughtUpStack.isHidden = !presentation.next.showsCaughtUp
        caughtUpLabel.stringValue = presentation.next.showsCaughtUp ? String(localized: "You're all caught up!") : ""
        nextTitleLabel.stringValue = presentation.next.title ?? ""
        nextDetailLabel.stringValue = presentation.next.detail ?? ""
        nextCoverView.configure(bookID: presentation.next.bookID)
      } else {
        nextContainer.isHidden = true
        nextBadgeLabel.isHidden = true
        nextCoverView.isHidden = true
        nextMetadataStack.isHidden = true
        caughtUpStack.isHidden = true
        caughtUpLabel.stringValue = ""
        nextTitleLabel.stringValue = ""
        nextDetailLabel.stringValue = ""
        nextCoverView.configure(bookID: nil)
      }

      EndPageCloseButtonStyle.apply(to: closeButton, textColor: textColor)
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
      let showsRelationHeader = !isPortrait && !presentation.relationTitle.isEmpty
      setArrangedSubviews(
        of: contentStack,
        with: [
          showsRelationHeader ? horizontalDividerStack : nil,
          sectionsStack,
          closeButton,
        ]
      )

      switch presentation.layoutMode(for: bounds.size, readingDirection: readingDirection) {
      case .singlePrevious:
        sectionsStack.orientation = .vertical
        previousCoverView.isHidden = previousBook == nil
        setArrangedSubviews(of: sectionsStack, with: [previousContainer])
      case .singleNext:
        sectionsStack.orientation = .vertical
        previousCoverView.isHidden = true
        setArrangedSubviews(of: sectionsStack, with: [nextContainer])
      case .stacked:
        sectionsStack.orientation = .vertical
        previousCoverView.isHidden = true
        setArrangedSubviews(
          of: sectionsStack,
          with: [previousContainer, horizontalDividerStack, nextContainer]
        )
      case .sideBySide(let nextOnLeadingSide, _):
        sectionsStack.orientation = .horizontal
        previousCoverView.isHidden = previousBook == nil
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

    private func setArrangedSubviews(of stack: NSStackView, with views: [NSView?]) {
      let filteredViews = views.compactMap { $0 }
      if stack.arrangedSubviews.elementsEqual(filteredViews, by: { $0 === $1 }) {
        return
      }

      sectionsEqualWidthConstraint?.isActive = false
      stack.setViews([], in: .center)
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
      sectionsEqualWidthConstraint?.isActive = sectionsStack.orientation == .horizontal
    }

    private func applyDynamicMetrics() {
      guard bounds.width > 0, bounds.height > 0 else { return }

      let isPortrait = bounds.height >= bounds.width
      let minDimension = min(bounds.width, bounds.height)
      let maxDimension = max(bounds.width, bounds.height)
      let outerPadding = clamped(minDimension * 0.08, lower: 20, upper: 56)
      let stackSpacing = clamped(minDimension * 0.034, lower: 12, upper: 22)
      let portraitSectionSpacing = stackSpacing + clamped(stackSpacing * 0.5, lower: 6, upper: 12)
      let horizontalDividerWidth = clamped(bounds.width * 0.78, lower: 260, upper: 680)
      let coverWidth = clamped(minDimension * (isPortrait ? 0.28 : 0.22), lower: 96, upper: 190)
      let coverHeight = coverWidth / CoverAspectRatio.widthToHeight
      let dividerHeight = clamped(maxDimension * 0.32, lower: 140, upper: 320)

      contentStack.spacing = stackSpacing
      sectionsStack.spacing = isPortrait ? portraitSectionSpacing : stackSpacing

      contentLeadingConstraint?.constant = outerPadding
      contentTrailingConstraint?.constant = -outerPadding
      contentTopConstraint?.constant = outerPadding
      contentBottomConstraint?.constant = -outerPadding
      contentMaxWidthConstraint?.constant = -outerPadding * 2
      horizontalDividerWidthConstraint?.constant = horizontalDividerWidth
      previousCoverWidthConstraint?.constant = coverWidth
      previousCoverHeightConstraint?.constant = coverHeight
      nextCoverWidthConstraint?.constant = coverWidth
      nextCoverHeightConstraint?.constant = coverHeight
      verticalDividerHeightConstraint?.constant = dividerHeight
    }

    private var shouldUseLightCoverShadow: Bool {
      switch renderConfig.readerBackground {
      case .black, .gray:
        return true
      case .white, .sepia:
        return false
      case .system:
        let bestMatch = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return bestMatch == .darkAqua
      }
    }

    private var coverBlendTintColor: NSColor? {
      renderConfig.readerBackground.appliesImageMultiplyBlend ? NSColor(renderConfig.readerBackground.color) : nil
    }

    private func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
      Swift.min(Swift.max(value, lower), upper)
    }

    @objc private func handleClose() {
      onDismiss?()
    }
  }
#endif
