//
// ReaderRenderConfig.swift
//
//

import Foundation

struct ReaderRenderConfig: Equatable {
  let tapZoneSize: TapZoneSize
  let tapZoneMode: TapZoneMode
  let showPageNumber: Bool
  let autoPlayAnimatedImages: Bool
  let readerBackground: ReaderBackground
  let enableLiveText: Bool
  let doubleTapZoomScale: Double
  let doubleTapZoomMode: DoubleTapZoomMode
}
