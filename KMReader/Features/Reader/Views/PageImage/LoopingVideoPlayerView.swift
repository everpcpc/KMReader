import AVFoundation
import SwiftUI

struct LoopingVideoPlayerView: View {
  let videoURL: URL
  let onLoadStateChange: ((Bool) -> Void)?

  init(videoURL: URL, onLoadStateChange: ((Bool) -> Void)? = nil) {
    self.videoURL = videoURL
    self.onLoadStateChange = onLoadStateChange
  }

  var body: some View {
    #if os(iOS) || os(macOS)
      PlatformVideoView(videoURL: videoURL, onLoadStateChange: onLoadStateChange)
        .background(Color.clear)
        .allowsHitTesting(false)
    #else
      Color.clear
    #endif
  }

  @MainActor
  private final class Coordinator {
    var onLoadStateChange: ((Bool) -> Void)?

    private var currentURL: URL?
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var statusObserver: NSKeyValueObservation?
    private var lastEmittedLoadState: Bool?
    private var loadStateEmissionToken: UInt64 = 0

    init(onLoadStateChange: ((Bool) -> Void)?) {
      self.onLoadStateChange = onLoadStateChange
    }

    func update(videoURL: URL, playerLayer: AVPlayerLayer) {
      if currentURL == videoURL, let player {
        if playerLayer.player !== player {
          playerLayer.player = player
        }
        player.play()
        emitLoadState(true)
        return
      }

      emitLoadState(false)
      teardown(playerLayer: playerLayer, emitNotReady: false)

      let item = AVPlayerItem(url: videoURL)
      let queuePlayer = AVQueuePlayer()
      queuePlayer.isMuted = true
      queuePlayer.actionAtItemEnd = .none
      queuePlayer.automaticallyWaitsToMinimizeStalling = false

      let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
      statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
        guard let self else { return }
        Task { @MainActor in
          switch observedItem.status {
          case .readyToPlay, .failed:
            self.emitLoadState(true)
          default:
            break
          }
        }
      }

      playerLayer.videoGravity = .resizeAspect
      playerLayer.player = queuePlayer

      currentURL = videoURL
      player = queuePlayer
      self.looper = looper
      queuePlayer.play()
    }

    func teardown(playerLayer: AVPlayerLayer, emitNotReady: Bool) {
      statusObserver?.invalidate()
      statusObserver = nil
      looper = nil
      player?.pause()
      player?.removeAllItems()
      player = nil
      currentURL = nil
      playerLayer.player = nil

      if emitNotReady {
        emitLoadState(false)
      }
    }

    private func emitLoadState(_ isReady: Bool) {
      guard lastEmittedLoadState != isReady else { return }
      lastEmittedLoadState = isReady
      loadStateEmissionToken &+= 1
      let token = loadStateEmissionToken
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        guard self.loadStateEmissionToken == token else { return }
        self.onLoadStateChange?(isReady)
      }
    }

    deinit {
      statusObserver?.invalidate()
      player?.pause()
      player?.removeAllItems()
    }
  }

  #if os(iOS)
    private struct PlatformVideoView: UIViewRepresentable {
      let videoURL: URL
      var onLoadStateChange: ((Bool) -> Void)?

      func makeCoordinator() -> Coordinator {
        Coordinator(onLoadStateChange: onLoadStateChange)
      }

      func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.backgroundColor = .clear
        return view
      }

      func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        context.coordinator.onLoadStateChange = onLoadStateChange
        context.coordinator.update(videoURL: videoURL, playerLayer: uiView.playerLayer)
      }

      static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.teardown(playerLayer: uiView.playerLayer, emitNotReady: true)
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
      var onLoadStateChange: ((Bool) -> Void)?

      func makeCoordinator() -> Coordinator {
        Coordinator(onLoadStateChange: onLoadStateChange)
      }

      func makeNSView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.wantsLayer = true
        view.layer?.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
        return view
      }

      func updateNSView(_ nsView: PlayerContainerView, context: Context) {
        context.coordinator.onLoadStateChange = onLoadStateChange
        context.coordinator.update(videoURL: videoURL, playerLayer: nsView.playerLayer)
      }

      static func dismantleNSView(_ nsView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.teardown(playerLayer: nsView.playerLayer, emitNotReady: true)
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
