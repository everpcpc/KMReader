//
// WebtoonLayout_iOS.swift
//
//

#if os(iOS)
  import UIKit

  class WebtoonLayout: UICollectionViewFlowLayout {
    var topContentPadding: CGFloat = 0 {
      didSet {
        guard abs(topContentPadding - oldValue) > WebtoonConstants.offsetEpsilon else { return }
        invalidateLayout()
      }
    }

    override func prepare() {
      super.prepare()
      scrollDirection = .vertical
      minimumLineSpacing = 0
      minimumInteritemSpacing = 0
      sectionInset = UIEdgeInsets(top: topContentPadding, left: 0, bottom: 0, right: 0)
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
      guard let collectionView = collectionView else { return true }
      return collectionView.bounds.size != newBounds.size
    }
  }
#endif
