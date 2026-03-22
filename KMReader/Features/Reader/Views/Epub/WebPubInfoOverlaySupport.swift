#if os(iOS) || os(macOS)
  import CoreGraphics
  import Foundation

  #if os(iOS)
    import UIKit
  #elseif os(macOS)
    import AppKit
  #endif

  enum WebPubInfoOverlaySupport {
  enum FlowStyle {
    case paged
    case scrolled
  }

  struct Entry {
    let text: String
    let isVisible: Bool

    static let hidden = Entry(text: "", isVisible: false)
  }

  struct Content {
    let topTitle: Entry
    let topProgress: Entry
    let bottomLeading: Entry
    let bottomCenter: Entry
    let bottomTrailing: Entry
  }

  static func containerInsets(topOffset: CGFloat, bottomOffset: CGFloat) -> ReaderContainerInsets {
    ReaderContainerInsets(top: topOffset + 24, left: 0, bottom: bottomOffset + 24, right: 0)
  }

  static func content(
    flowStyle: FlowStyle,
    bookTitle: String?,
    chapterTitle: String?,
    totalProgression: Double?,
    currentPageIndex: Int,
    totalPagesInChapter: Int,
    showingControls: Bool
  ) -> Content {
    let topTitle = showingControls
      ? Entry.hidden
      : visibleEntry(bookTitle)
    let topProgress: Entry
    if showingControls, let totalProgression {
      let percentage = String(format: "%.2f%%", totalProgression * 100)
      topProgress = Entry(
        text: String(localized: "Book Progress \(percentage)"),
        isVisible: true
      )
    } else {
      topProgress = .hidden
    }

    guard totalPagesInChapter > 0 else {
      return Content(
        topTitle: topTitle,
        topProgress: topProgress,
        bottomLeading: .hidden,
        bottomCenter: .hidden,
        bottomTrailing: .hidden
      )
    }

    if showingControls {
      return Content(
        topTitle: topTitle,
        topProgress: topProgress,
        bottomLeading: .hidden,
        bottomCenter: controlsCenterEntry(
          flowStyle: flowStyle,
          currentPageIndex: currentPageIndex,
          totalPagesInChapter: totalPagesInChapter
        ),
        bottomTrailing: .hidden
      )
    }

    return Content(
      topTitle: topTitle,
      topProgress: topProgress,
      bottomLeading: visibleEntry(chapterTitle),
      bottomCenter: .hidden,
      bottomTrailing: trailingEntry(
        flowStyle: flowStyle,
        currentPageIndex: currentPageIndex,
        totalPagesInChapter: totalPagesInChapter
      )
    )
  }

  private static func visibleEntry(_ text: String?) -> Entry {
    guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
      return .hidden
    }
    return Entry(text: trimmed, isVisible: true)
  }

  private static func controlsCenterEntry(
    flowStyle: FlowStyle,
    currentPageIndex: Int,
    totalPagesInChapter: Int
  ) -> Entry {
    switch flowStyle {
    case .paged:
      let current = currentPageIndex + 1
      return Entry(
        text: String(localized: "Chapter Progress \(current) / \(totalPagesInChapter)"),
        isVisible: true
      )
    case .scrolled:
      let progress = chapterProgress(
        currentPageIndex: currentPageIndex,
        totalPagesInChapter: totalPagesInChapter
      )
      let percentage = String(format: "%.1f%%", progress * 100)
      return Entry(
        text: String(localized: "Chapter Progress \(percentage)"),
        isVisible: true
      )
    }
  }

  private static func trailingEntry(
    flowStyle: FlowStyle,
    currentPageIndex: Int,
    totalPagesInChapter: Int
  ) -> Entry {
    switch flowStyle {
    case .paged:
      let remainingPages = totalPagesInChapter - (currentPageIndex + 1)
      let text = remainingPages > 0
        ? String(localized: "\(remainingPages) pages left")
        : String(localized: "Last page")
      return Entry(text: text, isVisible: true)
    case .scrolled:
      let progress = chapterProgress(
        currentPageIndex: currentPageIndex,
        totalPagesInChapter: totalPagesInChapter
      )
      let remaining = String(format: "%.1f%%", (1.0 - progress) * 100)
      return Entry(text: String(localized: "\(remaining) left"), isVisible: true)
    }
  }

  private static func chapterProgress(
    currentPageIndex: Int,
    totalPagesInChapter: Int
  ) -> Double {
    min(1.0, max(0.0, Double(currentPageIndex + 1) / Double(totalPagesInChapter)))
  }

  #if os(iOS)
    @MainActor
    final class UIKitOverlay {
      private let topTitleLabel: UILabel
      private let topProgressLabel: UILabel
      private let bottomLeadingLabel: UILabel
      private let bottomCenterLabel: UILabel
      private let bottomTrailingLabel: UILabel

      init(
        containerView: UIView,
        topAnchor: NSLayoutYAxisAnchor,
        bottomAnchor: NSLayoutYAxisAnchor,
        topOffset: CGFloat,
        bottomOffset: CGFloat,
        theme: ReaderTheme
      ) {
        topTitleLabel = Self.makeLabel(fontSize: 14, alignment: .center)
        topProgressLabel = Self.makeLabel(fontSize: 14, alignment: .center)
        bottomLeadingLabel = Self.makeLabel(fontSize: 12, alignment: .left)
        bottomCenterLabel = Self.makeLabel(fontSize: 12, alignment: .center, monospaced: true)
        bottomTrailingLabel = Self.makeLabel(fontSize: 12, alignment: .right, monospaced: true)

        let bottomConstant = -bottomOffset
        [topTitleLabel, topProgressLabel, bottomLeadingLabel, bottomCenterLabel, bottomTrailingLabel]
          .forEach(containerView.addSubview)

        NSLayoutConstraint.activate([
          topTitleLabel.topAnchor.constraint(equalTo: topAnchor, constant: topOffset),
          topTitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
          topTitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

          topProgressLabel.topAnchor.constraint(equalTo: topAnchor, constant: topOffset),
          topProgressLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
          topProgressLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

          bottomLeadingLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: bottomConstant),
          bottomLeadingLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),

          bottomCenterLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: bottomConstant),
          bottomCenterLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

          bottomTrailingLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: bottomConstant),
          bottomTrailingLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
          bottomTrailingLabel.leadingAnchor.constraint(greaterThanOrEqualTo: bottomLeadingLabel.trailingAnchor, constant: 8),
        ])

        apply(theme: theme)
      }

      func apply(theme: ReaderTheme) {
        let labelColor = theme.uiColorText.withAlphaComponent(0.6)
        [topTitleLabel, topProgressLabel, bottomLeadingLabel, bottomCenterLabel, bottomTrailingLabel]
          .forEach { $0.textColor = labelColor }
      }

      func update(content: Content, animated: Bool) {
        let updates = {
          self.apply(entry: content.topTitle, to: self.topTitleLabel)
          self.apply(entry: content.topProgress, to: self.topProgressLabel)
          self.apply(entry: content.bottomLeading, to: self.bottomLeadingLabel)
          self.apply(entry: content.bottomCenter, to: self.bottomCenterLabel)
          self.apply(entry: content.bottomTrailing, to: self.bottomTrailingLabel)
        }

        if animated {
          UIView.animate(withDuration: 0.2, animations: updates)
        } else {
          updates()
        }
      }

      private func apply(entry: Entry, to label: UILabel) {
        label.text = entry.text
        label.alpha = entry.isVisible ? 1.0 : 0.0
      }

      private static func makeLabel(
        fontSize: CGFloat,
        alignment: NSTextAlignment,
        monospaced: Bool = false
      ) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = monospaced
          ? UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
          : .systemFont(ofSize: fontSize)
        label.textAlignment = alignment
        label.isUserInteractionEnabled = false
        label.alpha = 0
        return label
      }
    }
  #elseif os(macOS)
    @MainActor
    final class AppKitOverlay {
      private let topTitleLabel: NSTextField
      private let topProgressLabel: NSTextField
      private let bottomLeadingLabel: NSTextField
      private let bottomCenterLabel: NSTextField
      private let bottomTrailingLabel: NSTextField

      init(
        containerView: NSView,
        topOffset: CGFloat,
        bottomOffset: CGFloat,
        theme: ReaderTheme
      ) {
        topTitleLabel = Self.makeLabel(fontSize: 14, alignment: .center)
        topProgressLabel = Self.makeLabel(fontSize: 14, alignment: .center)
        bottomLeadingLabel = Self.makeLabel(fontSize: 12, alignment: .left)
        bottomCenterLabel = Self.makeLabel(fontSize: 12, alignment: .center, monospaced: true)
        bottomTrailingLabel = Self.makeLabel(fontSize: 12, alignment: .right, monospaced: true)

        let bottomConstant = -bottomOffset
        [topTitleLabel, topProgressLabel, bottomLeadingLabel, bottomCenterLabel, bottomTrailingLabel]
          .forEach(containerView.addSubview)

        NSLayoutConstraint.activate([
          topTitleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: topOffset),
          topTitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
          topTitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

          topProgressLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: topOffset),
          topProgressLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
          topProgressLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

          bottomLeadingLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: bottomConstant),
          bottomLeadingLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),

          bottomCenterLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: bottomConstant),
          bottomCenterLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

          bottomTrailingLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: bottomConstant),
          bottomTrailingLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
          bottomTrailingLabel.leadingAnchor.constraint(greaterThanOrEqualTo: bottomLeadingLabel.trailingAnchor, constant: 8),
        ])

        apply(theme: theme)
      }

      func apply(theme: ReaderTheme) {
        let labelColor = (NSColor(hex: theme.textColorHex) ?? .labelColor).withAlphaComponent(0.6)
        [topTitleLabel, topProgressLabel, bottomLeadingLabel, bottomCenterLabel, bottomTrailingLabel]
          .forEach { $0.textColor = labelColor }
      }

      func update(content: Content) {
        apply(entry: content.topTitle, to: topTitleLabel)
        apply(entry: content.topProgress, to: topProgressLabel)
        apply(entry: content.bottomLeading, to: bottomLeadingLabel)
        apply(entry: content.bottomCenter, to: bottomCenterLabel)
        apply(entry: content.bottomTrailing, to: bottomTrailingLabel)
      }

      private func apply(entry: Entry, to label: NSTextField) {
        label.stringValue = entry.text
        label.alphaValue = entry.isVisible ? 1.0 : 0.0
      }

      private static func makeLabel(
        fontSize: CGFloat,
        alignment: NSTextAlignment,
        monospaced: Bool = false
      ) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        label.alignment = alignment
        label.alphaValue = 0
        label.font = monospaced
          ? .monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
          : .systemFont(ofSize: fontSize)
        return label
      }
    }
  #endif
  }
#endif
