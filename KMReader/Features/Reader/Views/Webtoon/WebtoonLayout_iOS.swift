//
// WebtoonLayout_iOS.swift
//
//

#if os(iOS)
  import UIKit

  class WebtoonLayout: UICollectionViewFlowLayout {
    override func prepare() {
      super.prepare()
      scrollDirection = .vertical
      minimumLineSpacing = 0
      minimumInteritemSpacing = 0
      sectionInset = .zero
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
      guard let collectionView = collectionView else { return true }
      return collectionView.bounds.size != newBounds.size
    }
  }
#endif
