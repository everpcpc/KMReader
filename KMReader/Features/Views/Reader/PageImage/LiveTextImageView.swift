//
//  LiveTextImageView.swift
//  KMReader
//
//  UIViewRepresentable/NSViewRepresentable wrapper for ImageView with VisionKit Live Text support
//

import SwiftUI

#if os(iOS)
  import UIKit
  import VisionKit

  struct LiveTextImageView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    func makeUIView(context: Context) -> LiveTextImageUIView {
      let imageView = LiveTextImageUIView()
      imageView.contentMode = .scaleAspectFit
      imageView.isUserInteractionEnabled = true
      imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
      imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
      imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

      if ImageAnalyzer.isSupported {
        imageView.addInteraction(context.coordinator.interaction)
      }

      return imageView
    }

    func updateUIView(_ imageView: LiveTextImageUIView, context: Context) {
      guard imageView.image !== image else { return }
      imageView.image = image

      if ImageAnalyzer.isSupported {
        context.coordinator.analyzeImage(image)
      }
    }

    func sizeThatFits(
      _ proposal: ProposedViewSize,
      uiView: LiveTextImageUIView,
      context: Context
    ) -> CGSize? {
      guard let image = uiView.image else { return nil }

      let imageSize = image.size
      guard imageSize.width > 0, imageSize.height > 0 else { return nil }

      let proposedWidth = proposal.width ?? imageSize.width
      let proposedHeight = proposal.height ?? imageSize.height

      let imageAspect = imageSize.width / imageSize.height
      let proposedAspect = proposedWidth / proposedHeight

      if imageAspect > proposedAspect {
        return CGSize(width: proposedWidth, height: proposedWidth / imageAspect)
      } else {
        return CGSize(width: proposedHeight * imageAspect, height: proposedHeight)
      }
    }

    @MainActor
    class Coordinator {
      let interaction = ImageAnalysisInteraction()
      private let analyzer = ImageAnalyzer()
      private var currentTask: Task<Void, Never>?

      func analyzeImage(_ image: UIImage) {
        currentTask?.cancel()
        currentTask = Task {
          let configuration = ImageAnalyzer.Configuration([.text])
          do {
            let analysis = try await analyzer.analyze(image, configuration: configuration)
            if !Task.isCancelled {
              interaction.analysis = analysis
              interaction.preferredInteractionTypes = .textSelection
            }
          } catch {
            if !Task.isCancelled {
              interaction.analysis = nil
            }
          }
        }
      }
    }
  }

  class LiveTextImageUIView: UIImageView {
    override var intrinsicContentSize: CGSize {
      guard let image = image else {
        return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
      }
      return image.size
    }
  }

#elseif os(macOS)
  import AppKit
  import VisionKit

  struct LiveTextImageView: NSViewRepresentable {
    let image: NSImage

    func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
      let containerView = NSView()

      let imageView = LiveTextImageNSView()
      imageView.imageScaling = .scaleProportionallyUpOrDown
      imageView.translatesAutoresizingMaskIntoConstraints = false
      imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
      imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
      imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
      containerView.addSubview(imageView)

      NSLayoutConstraint.activate([
        imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
        imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
        imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
      ])

      if ImageAnalyzer.isSupported {
        let overlayView = context.coordinator.overlayView
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.trackingImageView = imageView
        containerView.addSubview(overlayView)

        NSLayoutConstraint.activate([
          overlayView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
          overlayView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
          overlayView.topAnchor.constraint(equalTo: containerView.topAnchor),
          overlayView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
      }

      return containerView
    }

    func updateNSView(_ containerView: NSView, context: Context) {
      guard let imageView = containerView.subviews.first as? LiveTextImageNSView else { return }
      guard imageView.image !== image else { return }
      imageView.image = image

      if ImageAnalyzer.isSupported {
        context.coordinator.analyzeImage(image)
      }
    }

    func sizeThatFits(
      _ proposal: ProposedViewSize,
      nsView: NSView,
      context: Context
    ) -> CGSize? {
      guard let imageView = nsView.subviews.first as? LiveTextImageNSView,
        let image = imageView.image
      else { return nil }

      let imageSize = image.size
      guard imageSize.width > 0, imageSize.height > 0 else { return nil }

      let proposedWidth = proposal.width ?? imageSize.width
      let proposedHeight = proposal.height ?? imageSize.height

      let imageAspect = imageSize.width / imageSize.height
      let proposedAspect = proposedWidth / proposedHeight

      if imageAspect > proposedAspect {
        return CGSize(width: proposedWidth, height: proposedWidth / imageAspect)
      } else {
        return CGSize(width: proposedHeight * imageAspect, height: proposedHeight)
      }
    }

    @MainActor
    class Coordinator {
      let overlayView = ImageAnalysisOverlayView()
      private let analyzer = ImageAnalyzer()
      private var currentTask: Task<Void, Never>?

      func analyzeImage(_ image: NSImage) {
        currentTask?.cancel()
        currentTask = Task {
          let configuration = ImageAnalyzer.Configuration([.text])
          do {
            let analysis = try await analyzer.analyze(
              image, orientation: .up, configuration: configuration)
            if !Task.isCancelled {
              overlayView.analysis = analysis
              overlayView.preferredInteractionTypes = .textSelection
            }
          } catch {
            if !Task.isCancelled {
              overlayView.analysis = nil
            }
          }
        }
      }
    }
  }

  class LiveTextImageNSView: NSImageView {
    override var intrinsicContentSize: NSSize {
      guard let image = image else {
        return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
      }
      return image.size
    }
  }
#endif
