#if os(iOS) || os(tvOS)
  import CoreGraphics
  import UIKit

  nonisolated struct ReaderUpscaleDecision {
    nonisolated enum SkipReason {
      case disabled
      case belowAutoTriggerScale
      case exceedsAlwaysMaxScreenScale
      case invalidSourceSize
    }

    let shouldUpscale: Bool
    let requiredScale: CGFloat
    let reason: SkipReason?

    static func evaluate(
      mode: ReaderImageUpscalingMode,
      sourcePixelSize: CGSize,
      screenPixelSize: CGSize,
      autoTriggerScale: CGFloat,
      alwaysMaxScreenScale: CGFloat
    ) -> ReaderUpscaleDecision {
      guard sourcePixelSize.width > 0, sourcePixelSize.height > 0 else {
        return ReaderUpscaleDecision(
          shouldUpscale: false,
          requiredScale: 0,
          reason: .invalidSourceSize
        )
      }

      let requiredScale = min(
        screenPixelSize.width / sourcePixelSize.width,
        screenPixelSize.height / sourcePixelSize.height
      )

      guard mode != .disabled else {
        return ReaderUpscaleDecision(
          shouldUpscale: false,
          requiredScale: requiredScale,
          reason: .disabled
        )
      }

      switch mode {
      case .disabled:
        return ReaderUpscaleDecision(
          shouldUpscale: false,
          requiredScale: requiredScale,
          reason: .disabled
        )
      case .auto:
        let safeAutoTriggerScale = max(autoTriggerScale, 1.0)
        guard requiredScale > safeAutoTriggerScale else {
          return ReaderUpscaleDecision(
            shouldUpscale: false,
            requiredScale: requiredScale,
            reason: .belowAutoTriggerScale
          )
        }
      case .always:
        let safeAlwaysMaxScale = max(alwaysMaxScreenScale, 1.0)
        let maxAllowedWidth = screenPixelSize.width * safeAlwaysMaxScale
        let maxAllowedHeight = screenPixelSize.height * safeAlwaysMaxScale
        guard sourcePixelSize.width <= maxAllowedWidth, sourcePixelSize.height <= maxAllowedHeight
        else {
          return ReaderUpscaleDecision(
            shouldUpscale: false,
            requiredScale: requiredScale,
            reason: .exceedsAlwaysMaxScreenScale
          )
        }
      }

      return ReaderUpscaleDecision(
        shouldUpscale: true,
        requiredScale: requiredScale,
        reason: nil
      )
    }

    @MainActor
    static func screenPixelSize(for screen: UIScreen) -> CGSize {
      let size = screen.bounds.size
      let scale = screen.scale
      return CGSize(
        width: max(size.width * scale, 1),
        height: max(size.height * scale, 1)
      )
    }
  }
#endif
