//
// WebtoonFooterCell_macOS.swift
//
//

#if os(macOS)
  import AppKit
  import SwiftUI

  class WebtoonFooterCell: NSCollectionViewItem {
    var readerBackground: ReaderBackground = .system {
      didSet { applyBackground() }
    }

    private var previousBook: Book?
    private var nextBook: Book?
    private var readListContext: ReaderReadListContext?
    private var onDismiss: (() -> Void)?

    private let topRegionView = NSView()
    private let bottomRegionView = NSView()
    private let previousBookStack = NSStackView()
    private let previousBadgeLabel = NSTextField(labelWithString: "")
    private let previousTitleLabel = NSTextField(labelWithString: "")
    private let previousDetailLabel = NSTextField(labelWithString: "")

    private let dividerStack = NSStackView()
    private let leadingDivider = NSView()
    private let dividerTitleLabel = NSTextField(labelWithString: "")
    private let trailingDivider = NSView()

    private let nextBookStack = NSStackView()
    private let nextBadgeLabel = NSTextField(labelWithString: "")
    private let nextTitleLabel = NSTextField(labelWithString: "")
    private let nextDetailLabel = NSTextField(labelWithString: "")
    private let caughtUpLabel = NSTextField(labelWithString: "")

    private let closeButton = NSButton()

    override func loadView() {
      view = NSView()
      view.wantsLayer = true
      setupUI()
    }

    func configure(
      previousBook: Book?,
      nextBook: Book?,
      readListContext: ReaderReadListContext?,
      onDismiss: (() -> Void)?
    ) {
      self.previousBook = previousBook
      self.nextBook = nextBook
      self.readListContext = readListContext
      self.onDismiss = onDismiss
      applyContent()
    }

    private func setupUI() {
      topRegionView.translatesAutoresizingMaskIntoConstraints = false
      bottomRegionView.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(topRegionView)
      view.addSubview(bottomRegionView)

      previousBookStack.orientation = .vertical
      previousBookStack.alignment = .centerX
      previousBookStack.spacing = 6
      previousBookStack.translatesAutoresizingMaskIntoConstraints = false
      previousBookStack.setContentHuggingPriority(.required, for: .vertical)
      previousBookStack.setContentCompressionResistancePriority(.required, for: .vertical)
      topRegionView.addSubview(previousBookStack)

      previousBadgeLabel.alignment = .center
      previousBadgeLabel.maximumNumberOfLines = 1
      previousBadgeLabel.font = NSFont.preferredFont(forTextStyle: .caption1)
      previousBadgeLabel.stringValue = String(localized: "reader.previousBook").uppercased()
      previousBookStack.addArrangedSubview(previousBadgeLabel)

      previousTitleLabel.alignment = .center
      previousTitleLabel.maximumNumberOfLines = 2
      previousTitleLabel.font = NSFont.preferredFont(forTextStyle: .title3)
      previousBookStack.addArrangedSubview(previousTitleLabel)

      previousDetailLabel.alignment = .center
      previousDetailLabel.maximumNumberOfLines = 1
      previousDetailLabel.font = NSFont.preferredFont(forTextStyle: .caption1)
      previousBookStack.addArrangedSubview(previousDetailLabel)

      dividerStack.orientation = .horizontal
      dividerStack.alignment = .centerY
      dividerStack.spacing = 10
      dividerStack.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(dividerStack)

      leadingDivider.wantsLayer = true
      leadingDivider.translatesAutoresizingMaskIntoConstraints = false
      leadingDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true
      leadingDivider.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
      dividerStack.addArrangedSubview(leadingDivider)

      dividerTitleLabel.alignment = .center
      dividerTitleLabel.maximumNumberOfLines = 1
      dividerTitleLabel.font = NSFont.preferredFont(forTextStyle: .caption1)
      dividerStack.addArrangedSubview(dividerTitleLabel)

      trailingDivider.wantsLayer = true
      trailingDivider.translatesAutoresizingMaskIntoConstraints = false
      trailingDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true
      trailingDivider.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
      dividerStack.addArrangedSubview(trailingDivider)

      nextBookStack.orientation = .vertical
      nextBookStack.alignment = .centerX
      nextBookStack.spacing = 6
      nextBookStack.translatesAutoresizingMaskIntoConstraints = false
      nextBookStack.setContentHuggingPriority(.required, for: .vertical)
      nextBookStack.setContentCompressionResistancePriority(.required, for: .vertical)
      bottomRegionView.addSubview(nextBookStack)

      nextBadgeLabel.alignment = .center
      nextBadgeLabel.maximumNumberOfLines = 1
      nextBadgeLabel.font = NSFont.preferredFont(forTextStyle: .caption1)
      nextBadgeLabel.stringValue = String(localized: "reader.nextBook").uppercased()
      nextBookStack.addArrangedSubview(nextBadgeLabel)

      nextTitleLabel.alignment = .center
      nextTitleLabel.maximumNumberOfLines = 2
      nextTitleLabel.font = NSFont.preferredFont(forTextStyle: .title3)
      nextBookStack.addArrangedSubview(nextTitleLabel)

      nextDetailLabel.alignment = .center
      nextDetailLabel.maximumNumberOfLines = 1
      nextDetailLabel.font = NSFont.preferredFont(forTextStyle: .caption1)
      nextBookStack.addArrangedSubview(nextDetailLabel)

      caughtUpLabel.alignment = .center
      caughtUpLabel.maximumNumberOfLines = 2
      caughtUpLabel.font = NSFont.preferredFont(forTextStyle: .headline)
      nextBookStack.addArrangedSubview(caughtUpLabel)

      closeButton.bezelStyle = .rounded
      closeButton.target = self
      closeButton.action = #selector(handleClose)
      nextBookStack.addArrangedSubview(closeButton)

      NSLayoutConstraint.activate([
        dividerStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        dividerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 44),
        dividerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -44),

        topRegionView.topAnchor.constraint(equalTo: view.topAnchor, constant: 32),
        topRegionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 44),
        topRegionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -44),
        topRegionView.bottomAnchor.constraint(equalTo: dividerStack.topAnchor, constant: -12),

        bottomRegionView.topAnchor.constraint(equalTo: dividerStack.bottomAnchor, constant: 12),
        bottomRegionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 44),
        bottomRegionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -44),
        bottomRegionView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32),

        previousBookStack.centerXAnchor.constraint(equalTo: topRegionView.centerXAnchor),
        previousBookStack.centerYAnchor.constraint(equalTo: topRegionView.centerYAnchor),
        previousBookStack.leadingAnchor.constraint(
          greaterThanOrEqualTo: topRegionView.leadingAnchor),
        previousBookStack.trailingAnchor.constraint(
          lessThanOrEqualTo: topRegionView.trailingAnchor),

        nextBookStack.centerXAnchor.constraint(equalTo: bottomRegionView.centerXAnchor),
        nextBookStack.centerYAnchor.constraint(equalTo: bottomRegionView.centerYAnchor),
        nextBookStack.leadingAnchor.constraint(greaterThanOrEqualTo: bottomRegionView.leadingAnchor),
        nextBookStack.trailingAnchor.constraint(lessThanOrEqualTo: bottomRegionView.trailingAnchor),
      ])

      applyBackground()
      applyContent()
    }

    private func applyBackground() {
      view.layer?.backgroundColor = NSColor(readerBackground.color).cgColor
      let textColor = NSColor(readerBackground.contentColor)
      previousBadgeLabel.textColor = textColor.withAlphaComponent(0.55)
      previousTitleLabel.textColor = textColor
      previousDetailLabel.textColor = textColor.withAlphaComponent(0.6)
      dividerTitleLabel.textColor = textColor.withAlphaComponent(0.8)
      leadingDivider.layer?.backgroundColor = textColor.withAlphaComponent(0.3).cgColor
      trailingDivider.layer?.backgroundColor = textColor.withAlphaComponent(0.3).cgColor
      nextBadgeLabel.textColor = textColor.withAlphaComponent(0.55)
      nextTitleLabel.textColor = textColor
      nextDetailLabel.textColor = textColor.withAlphaComponent(0.6)
      caughtUpLabel.textColor = textColor
      EndPageCloseButtonStyle.apply(to: closeButton, textColor: textColor)
    }

    private func applyContent() {
      dividerTitleLabel.stringValue =
        readListContext?.name ?? previousBook?.seriesTitle ?? nextBook?.seriesTitle ?? ""

      if let previousBook {
        previousBookStack.isHidden = false
        previousTitleLabel.stringValue = previousBook.readerChapterTitle
        previousDetailLabel.stringValue = previousBook.readerChapterDetail
      } else {
        previousBookStack.isHidden = true
      }

      if let nextBook {
        closeButton.isHidden = true
        nextBadgeLabel.isHidden = false
        caughtUpLabel.isHidden = true
        nextTitleLabel.stringValue = nextBook.readerChapterTitle
        nextDetailLabel.stringValue = nextBook.readerChapterDetail
      } else {
        closeButton.isHidden = false
        nextBadgeLabel.isHidden = true
        nextTitleLabel.stringValue = ""
        nextDetailLabel.stringValue = ""
        caughtUpLabel.isHidden = false
        caughtUpLabel.stringValue = String(localized: "You're all caught up!")
      }

      EndPageCloseButtonStyle.apply(to: closeButton, textColor: NSColor(readerBackground.contentColor))
    }

    func isInteractingWithCloseButton(at point: NSPoint, in sourceView: NSView) -> Bool {
      guard !closeButton.isHidden else { return false }
      let localPoint = closeButton.convert(point, from: sourceView)
      return closeButton.bounds.contains(localPoint)
    }

    @objc private func handleClose() {
      onDismiss?()
    }
  }
#endif
