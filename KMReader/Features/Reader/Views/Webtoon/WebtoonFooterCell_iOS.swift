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

    private let containerStack = UIStackView()
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
      contentView.addSubview(containerStack)
      containerStack.translatesAutoresizingMaskIntoConstraints = false
      containerStack.axis = .vertical
      containerStack.alignment = .center
      containerStack.spacing = 20
      containerStack.isLayoutMarginsRelativeArrangement = true
      containerStack.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20)

      previousBookStack.axis = .vertical
      previousBookStack.alignment = .center
      previousBookStack.spacing = 6
      containerStack.addArrangedSubview(previousBookStack)

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
      containerStack.addArrangedSubview(dividerStack)

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
      containerStack.addArrangedSubview(nextBookStack)

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
      containerStack.addArrangedSubview(closeButton)

      NSLayoutConstraint.activate([
        containerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
        containerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
        containerStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
        containerStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
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
      closeButton.tintColor = textColor
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

      var configuration = UIButton.Configuration.bordered()
      configuration.image = UIImage(systemName: "xmark")
      configuration.imagePlacement = .leading
      configuration.imagePadding = 8
      configuration.title = String(localized: "Close")
      configuration.cornerStyle = .capsule
      closeButton.configuration = configuration
    }

    @objc private func handleClose() {
      onDismiss?()
    }
  }
#endif
