#if os(iOS) || os(tvOS)
  import UIKit

  final class NativePagedLayoutAwareCollectionView: UICollectionView {
    var onDidLayout: (() -> Void)?

    override func layoutSubviews() {
      super.layoutSubviews()
      onDidLayout?()
    }
  }
#endif
