//
// WebtoonFooterCell_iOS.swift
//
//

#if os(iOS)
  import SwiftUI
  import UIKit

  class WebtoonFooterCell: UICollectionViewCell {
    var readerBackground: ReaderBackground = .system {
      didSet { applyBackground() }
    }

    private var previousBook: Book?
    private var nextBook: Book?
    private var readListContext: ReaderReadListContext?
    private var onDismiss: (() -> Void)?

    private let topRegionView = UIView()
    private let bottomRegionView = UIView()
    private let previousBookStack = UIStackView()
    private let previousBadgeLabel = UILabel()
    private let previousTitleLabel = UILabel()
    private let previousDetailLabel = UILabel()

    private let dividerStack = UIStackView()
    private let leadingDivider = UIView()
    private let dividerTitleLabel = UILabel()
    private let trailingDivider = UIView()

    private let nextBookStack = UIStackView()
    private let nextBadgeLabel = UILabel()
    private let nextTitleLabel = UILabel()
    private let nextDetailLabel = UILabel()
    private let caughtUpLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    override init(frame: CGRect) {
      super.init(frame: frame)
      setupUI()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
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
      contentView.addSubview(topRegionView)
      contentView.addSubview(bottomRegionView)

      previousBookStack.axis = .vertical
      previousBookStack.alignment = .center
      previousBookStack.spacing = 6
      previousBookStack.translatesAutoresizingMaskIntoConstraints = false
      previousBookStack.setContentHuggingPriority(.required, for: .vertical)
      previousBookStack.setContentCompressionResistancePriority(.required, for: .vertical)
      topRegionView.addSubview(previousBookStack)

      previousBadgeLabel.numberOfLines = 1
      previousBadgeLabel.textAlignment = .center
      previousBadgeLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
      previousBadgeLabel.text = String(localized: "reader.previousBook").uppercased()
      previousBookStack.addArrangedSubview(previousBadgeLabel)

      previousTitleLabel.numberOfLines = 2
      previousTitleLabel.textAlignment = .center
      previousTitleLabel.font = UIFont.preferredFont(forTextStyle: .title3)
      previousBookStack.addArrangedSubview(previousTitleLabel)

      previousDetailLabel.numberOfLines = 1
      previousDetailLabel.textAlignment = .center
      previousDetailLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
      previousBookStack.addArrangedSubview(previousDetailLabel)

      dividerStack.axis = .horizontal
      dividerStack.alignment = .center
      dividerStack.spacing = 10
      dividerStack.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview(dividerStack)

      leadingDivider.translatesAutoresizingMaskIntoConstraints = false
      leadingDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true
      leadingDivider.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
      dividerStack.addArrangedSubview(leadingDivider)

      dividerTitleLabel.numberOfLines = 1
      dividerTitleLabel.textAlignment = .center
      dividerTitleLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
      dividerStack.addArrangedSubview(dividerTitleLabel)

      trailingDivider.translatesAutoresizingMaskIntoConstraints = false
      trailingDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true
      trailingDivider.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
      dividerStack.addArrangedSubview(trailingDivider)

      nextBookStack.axis = .vertical
      nextBookStack.alignment = .center
      nextBookStack.spacing = 6
      nextBookStack.translatesAutoresizingMaskIntoConstraints = false
      nextBookStack.setContentHuggingPriority(.required, for: .vertical)
      nextBookStack.setContentCompressionResistancePriority(.required, for: .vertical)
      bottomRegionView.addSubview(nextBookStack)

      nextBadgeLabel.numberOfLines = 1
      nextBadgeLabel.textAlignment = .center
      nextBadgeLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
      nextBadgeLabel.text = String(localized: "reader.nextBook").uppercased()
      nextBookStack.addArrangedSubview(nextBadgeLabel)

      nextTitleLabel.numberOfLines = 2
      nextTitleLabel.textAlignment = .center
      nextTitleLabel.font = UIFont.preferredFont(forTextStyle: .title3)
      nextBookStack.addArrangedSubview(nextTitleLabel)

      nextDetailLabel.numberOfLines = 1
      nextDetailLabel.textAlignment = .center
      nextDetailLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
      nextBookStack.addArrangedSubview(nextDetailLabel)

      caughtUpLabel.numberOfLines = 0
      caughtUpLabel.textAlignment = .center
      caughtUpLabel.font = UIFont.preferredFont(forTextStyle: .headline)
      nextBookStack.addArrangedSubview(caughtUpLabel)

      closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
      nextBookStack.addArrangedSubview(closeButton)

      NSLayoutConstraint.activate([
        dividerStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        dividerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 44),
        dividerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -44),

        topRegionView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
        topRegionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 44),
        topRegionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -44),
        topRegionView.bottomAnchor.constraint(equalTo: dividerStack.topAnchor, constant: -12),

        bottomRegionView.topAnchor.constraint(equalTo: dividerStack.bottomAnchor, constant: 12),
        bottomRegionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 44),
        bottomRegionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -44),
        bottomRegionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),

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
      contentView.backgroundColor = UIColor(readerBackground.color)
      let textColor = UIColor(readerBackground.contentColor)
      previousBadgeLabel.textColor = textColor.withAlphaComponent(0.55)
      previousTitleLabel.textColor = textColor
      previousDetailLabel.textColor = textColor.withAlphaComponent(0.6)
      dividerTitleLabel.textColor = textColor.withAlphaComponent(0.8)
      leadingDivider.backgroundColor = textColor.withAlphaComponent(0.3)
      trailingDivider.backgroundColor = textColor.withAlphaComponent(0.3)
      nextBadgeLabel.textColor = textColor.withAlphaComponent(0.55)
      nextTitleLabel.textColor = textColor
      nextDetailLabel.textColor = textColor.withAlphaComponent(0.6)
      caughtUpLabel.textColor = textColor
      EndPageCloseButtonStyle.apply(to: closeButton, textColor: textColor)
    }

    private func applyContent() {
      dividerTitleLabel.text = readListContext?.name ?? previousBook?.seriesTitle ?? nextBook?.seriesTitle

      if let previousBook {
        previousBookStack.isHidden = false
        previousTitleLabel.text = previousBook.readerChapterTitle
        previousDetailLabel.text = previousBook.readerChapterDetail
      } else {
        previousBookStack.isHidden = true
      }

      if let nextBook {
        closeButton.isHidden = true
        nextBadgeLabel.isHidden = false
        caughtUpLabel.isHidden = true
        nextTitleLabel.text = nextBook.readerChapterTitle
        nextDetailLabel.text = nextBook.readerChapterDetail
      } else {
        closeButton.isHidden = false
        nextBadgeLabel.isHidden = true
        nextTitleLabel.text = nil
        nextDetailLabel.text = nil
        caughtUpLabel.isHidden = false
        caughtUpLabel.text = String(localized: "You're all caught up!")
      }

      EndPageCloseButtonStyle.apply(to: closeButton, textColor: UIColor(readerBackground.contentColor))
    }

    @objc private func handleClose() {
      onDismiss?()
    }
  }
#endif
