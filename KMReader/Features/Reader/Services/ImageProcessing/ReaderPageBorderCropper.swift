//
// ReaderPageBorderCropper.swift
//
//

import CoreGraphics
import Foundation

nonisolated enum ReaderPageBorderCropper {
  static func crop(_ image: CGImage, mode: ReaderPageBorderCropMode) -> CGImage? {
    guard mode != .disabled else { return nil }
    guard let cropRect = cropRect(for: image, mode: mode) else { return nil }
    return image.cropping(to: cropRect)
  }

  static func cropRect(for image: CGImage, mode: ReaderPageBorderCropMode) -> CGRect? {
    guard mode != .disabled else { return nil }

    let sourceWidth = image.width
    let sourceHeight = image.height
    guard sourceWidth >= 64, sourceHeight >= 64 else { return nil }

    let parameters = parameters(for: mode)
    let analysisScale = min(1.0, parameters.downscale)
    let analysisWidth = max(1, Int((Double(sourceWidth) * analysisScale).rounded()))
    let analysisHeight = max(1, Int((Double(sourceHeight) * analysisScale).rounded()))
    guard let pixels = argbPixels(from: image, width: analysisWidth, height: analysisHeight) else { return nil }

    var minX = analysisWidth
    var minY = analysisHeight
    var maxX = -1
    var maxY = -1

    for y in 0..<analysisHeight {
      for x in 0..<analysisWidth {
        let index = (y * analysisWidth + x) * 4
        let alpha = Int(pixels[index])
        let red = Int(pixels[index + 1])
        let green = Int(pixels[index + 2])
        let blue = Int(pixels[index + 3])

        guard
          !isCropBackgroundPixel(
            alpha: alpha,
            red: red,
            green: green,
            blue: blue,
            parameters: parameters
          )
        else {
          continue
        }

        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x)
        maxY = max(maxY, y)
      }
    }

    guard maxX >= minX, maxY >= minY else { return nil }

    let paddingX = max(0, Int((Double(analysisWidth) * parameters.paddingRatio).rounded()))
    let paddingY = max(0, Int((Double(analysisHeight) * parameters.paddingRatio).rounded()))
    let paddedMinX = max(0, minX - paddingX)
    let paddedMinY = max(0, minY - paddingY)
    let paddedMaxX = min(analysisWidth - 1, maxX + paddingX)
    let paddedMaxY = min(analysisHeight - 1, maxY + paddingY)

    let cropWidth = paddedMaxX - paddedMinX + 1
    let cropHeight = paddedMaxY - paddedMinY + 1
    guard cropWidth > 0, cropHeight > 0 else { return nil }

    let retainedWidthRatio = Double(cropWidth) / Double(analysisWidth)
    let retainedHeightRatio = Double(cropHeight) / Double(analysisHeight)
    guard retainedWidthRatio >= parameters.minimumRetainedRatio,
      retainedHeightRatio >= parameters.minimumRetainedRatio
    else {
      return nil
    }

    let maxCropRatio = parameters.maxCropRatio
    let cropLeftRatio = Double(paddedMinX) / Double(analysisWidth)
    let cropRightRatio = Double(analysisWidth - 1 - paddedMaxX) / Double(analysisWidth)
    let cropTopRatio = Double(paddedMinY) / Double(analysisHeight)
    let cropBottomRatio = Double(analysisHeight - 1 - paddedMaxY) / Double(analysisHeight)
    guard [cropLeftRatio, cropRightRatio, cropTopRatio, cropBottomRatio].allSatisfy({ $0 <= maxCropRatio }) else {
      return nil
    }

    let sourceScaleX = Double(sourceWidth) / Double(analysisWidth)
    let sourceScaleY = Double(sourceHeight) / Double(analysisHeight)
    let sourceX = max(0, Int((Double(paddedMinX) * sourceScaleX).rounded(.down)))
    let sourceY = max(0, Int((Double(paddedMinY) * sourceScaleY).rounded(.down)))
    let sourceRight = min(sourceWidth, Int((Double(paddedMaxX + 1) * sourceScaleX).rounded(.up)))
    let sourceBottom = min(sourceHeight, Int((Double(paddedMaxY + 1) * sourceScaleY).rounded(.up)))

    guard sourceRight > sourceX, sourceBottom > sourceY else { return nil }
    guard sourceX > 0 || sourceY > 0 || sourceRight < sourceWidth || sourceBottom < sourceHeight else {
      return nil
    }

    return CGRect(x: sourceX, y: sourceY, width: sourceRight - sourceX, height: sourceBottom - sourceY)
  }

  private static func isCropBackgroundPixel(
    alpha: Int,
    red: Int,
    green: Int,
    blue: Int,
    parameters: CropParameters
  ) -> Bool {
    if alpha <= parameters.alphaThreshold { return true }
    if red >= parameters.whiteThreshold, green >= parameters.whiteThreshold, blue >= parameters.whiteThreshold {
      return true
    }
    if red <= parameters.blackThreshold, green <= parameters.blackThreshold, blue <= parameters.blackThreshold {
      return true
    }
    return false
  }

  private static func parameters(for mode: ReaderPageBorderCropMode) -> CropParameters {
    switch mode {
    case .disabled:
      return CropParameters(
        whiteThreshold: 238,
        blackThreshold: 5,
        alphaThreshold: 0,
        downscale: 0.4,
        paddingRatio: 0.018,
        maxCropRatio: 0.2,
        minimumRetainedRatio: 0.75
      )
    case .conservative:
      return CropParameters(
        whiteThreshold: 238,
        blackThreshold: 5,
        alphaThreshold: 0,
        downscale: 0.4,
        paddingRatio: 0.018,
        maxCropRatio: 0.2,
        minimumRetainedRatio: 0.75
      )
    case .aggressive:
      return CropParameters(
        whiteThreshold: 170,
        blackThreshold: 32,
        alphaThreshold: 0,
        downscale: 0.4,
        paddingRatio: 0,
        maxCropRatio: 0.6,
        minimumRetainedRatio: 0.35
      )
    }
  }

  private static func argbPixels(from image: CGImage, width: Int, height: Int) -> [UInt8]? {
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue

    guard
      let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo
      )
    else {
      return nil
    }

    context.interpolationQuality = .low
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return pixels
  }

  private struct CropParameters {
    let whiteThreshold: Int
    let blackThreshold: Int
    let alphaThreshold: Int
    let downscale: Double
    let paddingRatio: Double
    let maxCropRatio: Double
    let minimumRetainedRatio: Double
  }
}
