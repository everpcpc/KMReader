#if os(iOS) || os(tvOS)
  import Accelerate
  import CoreGraphics
  @preconcurrency import CoreML
  import Foundation

  nonisolated final class ReaderMultiArrayModel: ReaderImageProcessingModel {
    private let mlmodel: MLModel
    private let inputName: String
    private let outputName: String
    private let shape: [Int]
    private let blockSize: Int
    private let shrinkSize: Int
    private let scale: Int

    nonisolated required init?(model: MLModel, descriptor: ReaderUpscaleModelDescriptor) {
      self.mlmodel = model
      let cfg = descriptor.config
      self.inputName = cfg?.inputName ?? "input"
      self.outputName = cfg?.outputName ?? "output"
      self.blockSize = cfg?.blockSize ?? 256
      self.shrinkSize = cfg?.shrinkSize ?? 0
      self.scale = cfg?.scale ?? 2

      if let customShape = cfg?.shape, !customShape.isEmpty {
        self.shape = customShape
      } else {
        self.shape = [1, 3, self.blockSize, self.blockSize]
      }
    }

    nonisolated func process(_ image: CGImage) async -> CGImage? {
      let mlmodel = self.mlmodel
      let inputName = self.inputName
      let outputName = self.outputName
      let shape = self.shape
      let blockSize = self.blockSize
      let shrinkSize = self.shrinkSize
      let scale = self.scale

      return await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
          continuation.resume(
            returning: Self.processSync(
              image,
              mlmodel: mlmodel,
              inputName: inputName,
              outputName: outputName,
              shape: shape,
              blockSize: blockSize,
              shrinkSize: shrinkSize,
              scale: scale
            ))
        }
      }
    }

    private static func processSync(
      _ image: CGImage,
      mlmodel: MLModel,
      inputName: String,
      outputName: String,
      shape: [Int],
      blockSize: Int,
      shrinkSize: Int,
      scale: Int
    ) -> CGImage? {
      let width = image.width
      let height = image.height
      guard width > 0, height > 0 else { return nil }

      let channels = 4
      let modelBlockSize = blockSize - shrinkSize * 2
      guard modelBlockSize > 0 else { return nil }

      let outScale = max(scale, 1)
      let outWidth = width * outScale
      let outHeight = height * outScale
      let outBlockSize = modelBlockSize * outScale
      let blockAndShrink = modelBlockSize + 2 * shrinkSize
      let channelStride = blockAndShrink * blockAndShrink
      let expandedWidth = width + 2 * shrinkSize
      let expandedHeight = height + 2 * shrinkSize

      let inputShape = shape.map { NSNumber(value: $0) }
      guard let input = try? MLMultiArray(shape: inputShape, dataType: .float32) else {
        return nil
      }

      let expanded = image.expand(shrinkSize: shrinkSize)
      let rects = Self.calculateRects(width: width, height: height, blockSize: modelBlockSize)
      var imgData = [UInt8](repeating: 0, count: outWidth * outHeight * channels)

      for rect in rects {
        let x = Int(rect.origin.x)
        let y = Int(rect.origin.y)
        let floatPtr = input.dataPointer.assumingMemoryBound(to: Float32.self)

        for yExp in y..<(y + blockAndShrink) {
          guard yExp >= 0 else { continue }
          for xExp in x..<(x + blockAndShrink) {
            guard xExp >= 0 else { continue }

            let baseIdx = (yExp - y) * blockAndShrink + (xExp - x)
            let basePixel = yExp * expandedWidth + xExp
            floatPtr[baseIdx] = Float32(expanded[basePixel])
            floatPtr[baseIdx + channelStride] = Float32(expanded[basePixel + expandedWidth * expandedHeight])
            floatPtr[baseIdx + channelStride * 2] = Float32(expanded[basePixel + expandedWidth * expandedHeight * 2])
          }
        }

        guard
          let prediction = try? mlmodel.prediction(
            inputName: inputName,
            outputName: outputName,
            input: input
          )
        else {
          continue
        }

        let originX = x * outScale
        let originY = y * outScale
        let dataPointer = prediction.dataPointer.assumingMemoryBound(to: Float32.self)

        for channel in 0..<3 {
          let channelOffset = outBlockSize * outBlockSize * channel
          let src = dataPointer.advanced(by: channelOffset)
          let count = outBlockSize * outBlockSize
          var tempBlock = [UInt8](repeating: 0, count: count)
          Self.normalize(src, &tempBlock, count: count)

          for srcY in 0..<outBlockSize {
            for srcX in 0..<outBlockSize {
              let destX = originX + srcX
              let destY = originY + srcY
              guard destX >= 0, destY >= 0, destX < outWidth, destY < outHeight else { continue }
              let destIndex = (destY * outWidth + destX) * channels + channel
              let srcIndex = srcY * outBlockSize + srcX
              imgData[destIndex] = tempBlock[srcIndex]
            }
          }
        }
      }

      for i in stride(from: 3, to: imgData.count, by: 4) {
        imgData[i] = 255
      }

      guard
        let cfBuffer = CFDataCreate(nil, &imgData, outWidth * outHeight * channels),
        let provider = CGDataProvider(data: cfBuffer)
      else {
        return nil
      }

      let colorSpace = CGColorSpaceCreateDeviceRGB()
      let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue

      return CGImage(
        width: outWidth,
        height: outHeight,
        bitsPerComponent: 8,
        bitsPerPixel: 8 * channels,
        bytesPerRow: outWidth * channels,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
        provider: provider,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
      )
    }

    private static func normalize(
      _ src: UnsafePointer<Float32>,
      _ dst: UnsafeMutablePointer<UInt8>,
      count: Int
    ) {
      var scale: Float32 = 255
      var minVal: Float32 = 0
      var maxVal: Float32 = 255
      var tempMul = [Float32](repeating: 0, count: count)
      var tempClip = [Float32](repeating: 0, count: count)
      vDSP_vsmul(src, 1, &scale, &tempMul, 1, vDSP_Length(count))
      vDSP_vclip(&tempMul, 1, &minVal, &maxVal, &tempClip, 1, vDSP_Length(count))
      vDSP_vfixu8(&tempClip, 1, dst, 1, vDSP_Length(count))
    }

    private static func calculateRects(width: Int, height: Int, blockSize: Int) -> [CGRect] {
      var rects: [CGRect] = []
      let numW = width / blockSize
      let numH = height / blockSize
      let remW = width % blockSize
      let remH = height % blockSize

      for i in 0..<numW {
        for j in 0..<numH {
          rects.append(CGRect(x: i * blockSize, y: j * blockSize, width: blockSize, height: blockSize))
        }
      }

      if remW > 0 {
        for j in 0..<numH {
          rects.append(CGRect(x: width - blockSize, y: j * blockSize, width: blockSize, height: blockSize))
        }
      }

      if remH > 0 {
        for i in 0..<numW {
          rects.append(CGRect(x: i * blockSize, y: height - blockSize, width: blockSize, height: blockSize))
        }
      }

      if remW > 0 && remH > 0 {
        rects.append(CGRect(x: width - blockSize, y: height - blockSize, width: blockSize, height: blockSize))
      }

      return rects
    }
  }

  private nonisolated final class ReaderMLInput: MLFeatureProvider {
    let input: MLMultiArray
    let featureNames: Set<String>

    init(name: String, input: MLMultiArray) {
      self.input = input
      self.featureNames = [name]
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
      MLFeatureValue(multiArray: input)
    }
  }

  extension MLModel {
    fileprivate nonisolated func prediction(inputName: String, outputName: String, input: MLMultiArray) throws
      -> MLMultiArray?
    {
      let inputProvider = ReaderMLInput(name: inputName, input: input)
      let outFeatures = try prediction(from: inputProvider)
      return outFeatures.featureValue(for: outputName)?.multiArrayValue
    }
  }

  extension CGImage {
    fileprivate nonisolated func expand(shrinkSize: Int) -> [Float] {
      let clipEta8: Float = 0.00196078411
      let exWidth = width + 2 * shrinkSize
      let exHeight = height + 2 * shrinkSize

      var rgba = [UInt8](repeating: 0, count: width * height * 4)
      rgba.withUnsafeMutableBytes { buffer in
        let context = CGContext(
          data: buffer.baseAddress,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: 4 * width,
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
      }

      let mainW = width
      let mainH = height
      let offsetX = shrinkSize
      let offsetY = shrinkSize

      var arr = [Float](repeating: 0, count: 3 * exWidth * exHeight)
      var rArr = [Float](repeating: 0, count: mainW * mainH)
      var gArr = [Float](repeating: 0, count: mainW * mainH)
      var bArr = [Float](repeating: 0, count: mainW * mainH)

      rgba.withUnsafeBufferPointer { buf in
        guard let src = buf.baseAddress else { return }
        var scale: Float = 1 / 255
        var eta = clipEta8

        var temp = [Float](repeating: 0, count: mainW * mainH)
        var out = [Float](repeating: 0, count: mainW * mainH)

        vDSP_vfltu8(src, 4, &temp, 1, vDSP_Length(mainW * mainH))
        vDSP_vsmsa(&temp, 1, &scale, &eta, &out, 1, vDSP_Length(mainW * mainH))
        rArr = out

        vDSP_vfltu8(src.advanced(by: 1), 4, &temp, 1, vDSP_Length(mainW * mainH))
        vDSP_vsmsa(&temp, 1, &scale, &eta, &out, 1, vDSP_Length(mainW * mainH))
        gArr = out

        vDSP_vfltu8(src.advanced(by: 2), 4, &temp, 1, vDSP_Length(mainW * mainH))
        vDSP_vsmsa(&temp, 1, &scale, &eta, &out, 1, vDSP_Length(mainW * mainH))
        bArr = out
      }

      for channel in 0..<3 {
        let src = channel == 0 ? rArr : (channel == 1 ? gArr : bArr)
        for y in 0..<mainH {
          let srcRow = y * mainW
          let dstStart = (channel * exWidth * exHeight) + (offsetY + y) * exWidth + offsetX
          arr[dstStart..<(dstStart + mainW)].withUnsafeMutableBufferPointer { dstBuf in
            src[srcRow..<(srcRow + mainW)].withUnsafeBufferPointer { srcBuf in
              if let srcAddress = srcBuf.baseAddress {
                dstBuf.baseAddress?.update(from: srcAddress, count: mainW)
              }
            }
          }
        }
      }

      func fillRegion(channel: Int, xRange: Range<Int>, yRange: Range<Int>, value: Float) {
        let base = channel * exWidth * exHeight
        for y in yRange {
          let rowStart = base + y * exWidth
          arr.replaceSubrange(
            (rowStart + xRange.lowerBound)..<(rowStart + xRange.upperBound),
            with: repeatElement(value, count: xRange.count)
          )
        }
      }

      let tlR = rArr[0] - clipEta8
      let tlG = gArr[0] - clipEta8
      let tlB = bArr[0] - clipEta8
      fillRegion(channel: 0, xRange: 0..<shrinkSize, yRange: 0..<shrinkSize, value: tlR)
      fillRegion(channel: 1, xRange: 0..<shrinkSize, yRange: 0..<shrinkSize, value: tlG)
      fillRegion(channel: 2, xRange: 0..<shrinkSize, yRange: 0..<shrinkSize, value: tlB)

      let trR = rArr[mainW - 1] - clipEta8
      let trG = gArr[mainW - 1] - clipEta8
      let trB = bArr[mainW - 1] - clipEta8
      fillRegion(channel: 0, xRange: width + shrinkSize..<(width + 2 * shrinkSize), yRange: 0..<shrinkSize, value: trR)
      fillRegion(channel: 1, xRange: width + shrinkSize..<(width + 2 * shrinkSize), yRange: 0..<shrinkSize, value: trG)
      fillRegion(channel: 2, xRange: width + shrinkSize..<(width + 2 * shrinkSize), yRange: 0..<shrinkSize, value: trB)

      let blR = rArr[(mainH - 1) * mainW] - clipEta8
      let blG = gArr[(mainH - 1) * mainW] - clipEta8
      let blB = bArr[(mainH - 1) * mainW] - clipEta8
      fillRegion(
        channel: 0, xRange: 0..<shrinkSize, yRange: height + shrinkSize..<(height + 2 * shrinkSize), value: blR)
      fillRegion(
        channel: 1, xRange: 0..<shrinkSize, yRange: height + shrinkSize..<(height + 2 * shrinkSize), value: blG)
      fillRegion(
        channel: 2, xRange: 0..<shrinkSize, yRange: height + shrinkSize..<(height + 2 * shrinkSize), value: blB)

      let brR = rArr[mainW * mainH - 1] - clipEta8
      let brG = gArr[mainW * mainH - 1] - clipEta8
      let brB = bArr[mainW * mainH - 1] - clipEta8
      fillRegion(
        channel: 0, xRange: width + shrinkSize..<(width + 2 * shrinkSize),
        yRange: height + shrinkSize..<(height + 2 * shrinkSize), value: brR)
      fillRegion(
        channel: 1, xRange: width + shrinkSize..<(width + 2 * shrinkSize),
        yRange: height + shrinkSize..<(height + 2 * shrinkSize), value: brG)
      fillRegion(
        channel: 2, xRange: width + shrinkSize..<(width + 2 * shrinkSize),
        yRange: height + shrinkSize..<(height + 2 * shrinkSize), value: brB)

      for x in 0..<width {
        let topR = rArr[x] - clipEta8
        let topG = gArr[x] - clipEta8
        let topB = bArr[x] - clipEta8
        let botR = rArr[(mainH - 1) * mainW + x] - clipEta8
        let botG = gArr[(mainH - 1) * mainW + x] - clipEta8
        let botB = bArr[(mainH - 1) * mainW + x] - clipEta8
        let xx = x + shrinkSize

        fillRegion(channel: 0, xRange: xx..<(xx + 1), yRange: 0..<shrinkSize, value: topR)
        fillRegion(channel: 1, xRange: xx..<(xx + 1), yRange: 0..<shrinkSize, value: topG)
        fillRegion(channel: 2, xRange: xx..<(xx + 1), yRange: 0..<shrinkSize, value: topB)

        fillRegion(
          channel: 0, xRange: xx..<(xx + 1), yRange: height + shrinkSize..<(height + 2 * shrinkSize), value: botR)
        fillRegion(
          channel: 1, xRange: xx..<(xx + 1), yRange: height + shrinkSize..<(height + 2 * shrinkSize), value: botG)
        fillRegion(
          channel: 2, xRange: xx..<(xx + 1), yRange: height + shrinkSize..<(height + 2 * shrinkSize), value: botB)
      }

      for y in 0..<height {
        let leftR = rArr[y * mainW] - clipEta8
        let leftG = gArr[y * mainW] - clipEta8
        let leftB = bArr[y * mainW] - clipEta8
        let rightR = rArr[y * mainW + mainW - 1] - clipEta8
        let rightG = gArr[y * mainW + mainW - 1] - clipEta8
        let rightB = bArr[y * mainW + mainW - 1] - clipEta8
        let yy = y + shrinkSize

        fillRegion(channel: 0, xRange: 0..<shrinkSize, yRange: yy..<(yy + 1), value: leftR)
        fillRegion(channel: 1, xRange: 0..<shrinkSize, yRange: yy..<(yy + 1), value: leftG)
        fillRegion(channel: 2, xRange: 0..<shrinkSize, yRange: yy..<(yy + 1), value: leftB)

        fillRegion(
          channel: 0, xRange: width + shrinkSize..<(width + 2 * shrinkSize), yRange: yy..<(yy + 1), value: rightR)
        fillRegion(
          channel: 1, xRange: width + shrinkSize..<(width + 2 * shrinkSize), yRange: yy..<(yy + 1), value: rightG)
        fillRegion(
          channel: 2, xRange: width + shrinkSize..<(width + 2 * shrinkSize), yRange: yy..<(yy + 1), value: rightB)
      }

      return arr
    }
  }
#endif
