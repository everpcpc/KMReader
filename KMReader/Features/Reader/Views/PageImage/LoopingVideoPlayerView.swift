import AVFoundation
import SwiftUI

struct LoopingVideoPlayerView: View {
  let videoURL: URL

  var body: some View {
    #if os(iOS) || os(macOS)
      PlatformVideoView(videoURL: videoURL)
        .background(Color.clear)
        .allowsHitTesting(false)
    #else
      Color.clear
    #endif
  }

  @MainActor
  private final class Coordinator {
    private var currentURL: URL?
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    func update(videoURL: URL, playerLayer: AVPlayerLayer) {
      if currentURL == videoURL, let player {
        if playerLayer.player !== player {
          playerLayer.player = player
        }
        player.play()
        return
      }

      teardown(playerLayer: playerLayer)

      let item = AVPlayerItem(url: videoURL)
      let queuePlayer = AVQueuePlayer()
      queuePlayer.isMuted = true
      queuePlayer.actionAtItemEnd = .none
      queuePlayer.automaticallyWaitsToMinimizeStalling = false

      looper = AVPlayerLooper(player: queuePlayer, templateItem: item)

      playerLayer.videoGravity = .resizeAspect
      playerLayer.player = queuePlayer

      currentURL = videoURL
      player = queuePlayer
      queuePlayer.play()
    }

    func teardown(playerLayer: AVPlayerLayer) {
      looper = nil
      player?.pause()
      player?.removeAllItems()
      player = nil
      currentURL = nil
      playerLayer.player = nil
    }

    deinit {
      player?.pause()
      player?.removeAllItems()
    }
  }

  #if os(iOS)
    private struct PlatformVideoView: UIViewRepresentable {
      let videoURL: URL

      func makeCoordinator() -> Coordinator {
        Coordinator()
      }

      func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.backgroundColor = .clear
        return view
      }

      func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        context.coordinator.update(videoURL: videoURL, playerLayer: uiView.playerLayer)
      }

      static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.teardown(playerLayer: uiView.playerLayer)
      }

      final class PlayerContainerView: UIView {
        override class var layerClass: AnyClass {
          AVPlayerLayer.self
        }

        var playerLayer: AVPlayerLayer {
          layer as! AVPlayerLayer
        }
      }
    }
  #elseif os(macOS)
    private struct PlatformVideoView: NSViewRepresentable {
      let videoURL: URL

      func makeCoordinator() -> Coordinator {
        Coordinator()
      }

      func makeNSView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.wantsLayer = true
        view.layer?.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
        return view
      }

      func updateNSView(_ nsView: PlayerContainerView, context: Context) {
        context.coordinator.update(videoURL: videoURL, playerLayer: nsView.playerLayer)
      }

      static func dismantleNSView(_ nsView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.teardown(playerLayer: nsView.playerLayer)
      }

      final class PlayerContainerView: NSView {
        override init(frame frameRect: NSRect) {
          super.init(frame: frameRect)
          wantsLayer = true
          layer = AVPlayerLayer()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
          fatalError("init(coder:) has not been implemented")
        }

        var playerLayer: AVPlayerLayer {
          layer as! AVPlayerLayer
        }
      }
    }
  #endif
}
