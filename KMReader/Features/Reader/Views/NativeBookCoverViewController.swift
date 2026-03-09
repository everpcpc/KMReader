//
// NativeBookCoverViewController.swift
//

#if os(iOS)
  import UIKit

  @MainActor
  final class NativeBookCoverViewController: UIViewController {
    private let coverView = NativeBookCoverView()

    var useLightShadow: Bool = false {
      didSet {
        coverView.useLightShadow = useLightShadow
      }
    }

    var imageBlendTintColor: UIColor? {
      didSet {
        coverView.imageBlendTintColor = imageBlendTintColor
      }
    }

    var cornerRadius: CGFloat = 12 {
      didSet {
        coverView.cornerRadius = cornerRadius
      }
    }

    override func loadView() {
      view = coverView
    }

    override func viewDidLoad() {
      super.viewDidLoad()
      coverView.useLightShadow = useLightShadow
      coverView.imageBlendTintColor = imageBlendTintColor
      coverView.cornerRadius = cornerRadius
    }

    func configure(bookID: String?) {
      coverView.configure(bookID: bookID)
    }
  }
#endif
