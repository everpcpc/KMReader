#if os(iOS) || os(tvOS)
  import SwiftUI
  import UIKit

  final class NativePagedEndCell: UICollectionViewCell {
    private let endPageView = NativeEndPageContentView()

    override init(frame: CGRect) {
      super.init(frame: frame)
      setupUI()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
      super.prepareForReuse()
      endPageView.configure(
        previousBook: nil,
        nextBook: nil,
        readListContext: nil,
        readingDirection: .ltr,
        renderConfig: placeholderRenderConfig,
        onDismiss: nil
      )
    }

    func configure(
      previousBook: Book?,
      nextBook: Book?,
      readListContext: ReaderReadListContext?,
      readingDirection: ReadingDirection,
      renderConfig: ReaderRenderConfig,
      onDismiss: (() -> Void)?
    ) {
      endPageView.configure(
        previousBook: previousBook,
        nextBook: nextBook,
        readListContext: readListContext,
        readingDirection: readingDirection,
        renderConfig: renderConfig,
        onDismiss: onDismiss
      )
    }

    private func setupUI() {
      backgroundColor = .clear
      contentView.addSubview(endPageView)
      endPageView.translatesAutoresizingMaskIntoConstraints = false

      NSLayoutConstraint.activate([
        endPageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        endPageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        endPageView.topAnchor.constraint(equalTo: contentView.topAnchor),
        endPageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      ])
    }

    private var placeholderRenderConfig: ReaderRenderConfig {
      ReaderRenderConfig(
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
    }
  }
#endif
