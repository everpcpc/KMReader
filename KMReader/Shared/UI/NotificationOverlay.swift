//
//  NotificationOverlay.swift
//  KMReader
//

import SwiftUI

#if os(iOS) || os(tvOS)
  import UIKit

  // Window-based notification manager for displaying notifications above sheets
  @MainActor
  class NotificationWindowManager {
    static let shared = NotificationWindowManager()

    private var notificationWindow: UIWindow?
    private var hostingController: StatusBarObservingHostingController<NotificationContentView>?

    private init() {}

    func setup(readerPresentation: ReaderPresentationManager) {
      guard notificationWindow == nil else { return }

      // Find the active window scene
      guard
        let windowScene = UIApplication.shared.connectedScenes
          .compactMap({ $0 as? UIWindowScene })
          .first(where: { $0.activationState == .foregroundActive })
          ?? UIApplication.shared.connectedScenes
          .compactMap({ $0 as? UIWindowScene })
          .first
      else { return }

      let window = PassthroughWindow(windowScene: windowScene)
      window.windowLevel = .alert + 1
      window.backgroundColor = .clear

      let hostingController = StatusBarObservingHostingController(
        rootView: NotificationContentView(),
        readerPresentation: readerPresentation
      )
      hostingController.view.backgroundColor = .clear
      window.rootViewController = hostingController

      window.isHidden = false
      window.isUserInteractionEnabled = true

      self.notificationWindow = window
      self.hostingController = hostingController
    }
  }

  // A window that passes through touches to the underlying window
  private class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
      guard let hitView = super.hitTest(point, with: event) else { return nil }
      // Pass through if hitting the root view or hosting controller's empty area
      return hitView == rootViewController?.view ? nil : hitView
    }
  }

  // A hosting controller that observes ReaderPresentationManager for UI preferences.
  // This is needed because this window has a higher windowLevel and iOS uses the
  // topmost window's rootViewController to determine:
  // - Status bar visibility (prefersStatusBarHidden)
  // - Home indicator auto-hide (prefersHomeIndicatorAutoHidden)
  // - Screen edge gesture deferral (preferredScreenEdgesDeferringSystemGestures)
  private class StatusBarObservingHostingController<Content: View>: UIHostingController<Content> {
    private let readerPresentation: ReaderPresentationManager

    init(rootView: Content, readerPresentation: ReaderPresentationManager) {
      self.readerPresentation = readerPresentation
      super.init(rootView: rootView)

      // Observe hideStatusBar changes using withObservationTracking
      Task { @MainActor [weak self] in
        self?.startObserving()
      }
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    private func startObserving() {
      withObservationTracking {
        _ = readerPresentation.hideStatusBar
      } onChange: { [weak self] in
        guard let self = self else { return }
        Task { @MainActor [weak self] in
          #if os(iOS)
            self?.setNeedsStatusBarAppearanceUpdate()
            self?.setNeedsUpdateOfHomeIndicatorAutoHidden()
          #endif
          self?.startObserving()
        }
      }
    }

    #if os(iOS)
      override var prefersStatusBarHidden: Bool {
        return readerPresentation.hideStatusBar
      }

      override var prefersHomeIndicatorAutoHidden: Bool {
        return readerPresentation.hideStatusBar
      }

    // NOTE: If users report accidental system gesture triggers while reading,
    // consider implementing preferredScreenEdgesDeferringSystemGestures.
    // This would require the first swipe from an edge to trigger app gestures,
    // and the second swipe to trigger system gestures.
    //
    // Example implementation:
    // override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
    //   return readerPresentation.hideStatusBar ? [.bottom, .top] : []
    // }
    //
    // Also add in startObserving():
    // self?.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    #endif
  }

  // The actual notification content view
  struct NotificationContentView: View {
    @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

    @State private var errorManager = ErrorManager.shared

    var body: some View {
      VStack(alignment: .center) {
        Spacer()
        ForEach($errorManager.notifications, id: \.self) { $notification in
          Text(notification)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .foregroundStyle(.white)
            .background(themeColor.color)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 10)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
      }
      .animation(.default, value: errorManager.notifications)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.horizontal, 8)
      .padding(.bottom, 64)
      .alert(String(localized: "error.title"), isPresented: $errorManager.hasAlert) {
        Button(String(localized: "common.ok")) {
          ErrorManager.shared.vanishError()
        }
        #if os(iOS)
          Button(String(localized: "common.copy")) {
            PlatformHelper.generalPasteboard.string = errorManager.currentError?.description
            ErrorManager.shared.notify(message: String(localized: "notification.copied"))
          }
        #endif
      } message: {
        if let error = errorManager.currentError {
          Text(verbatim: error.description)
        } else {
          Text(String(localized: "error.unknown"))
        }
      }
    }
  }

  // Modifier to setup the notification window
  struct NotificationWindowSetup: ViewModifier {
    @Environment(ReaderPresentationManager.self) private var readerPresentation

    func body(content: Content) -> some View {
      content
        .onAppear {
          NotificationWindowManager.shared.setup(readerPresentation: readerPresentation)
        }
    }
  }

  extension View {
    func setupNotificationWindow() -> some View {
      modifier(NotificationWindowSetup())
    }
  }

#elseif os(macOS)
  // macOS uses regular overlay approach since sheets behave differently
  struct NotificationOverlay: View {
    @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

    @State private var errorManager = ErrorManager.shared

    var body: some View {
      VStack(alignment: .center) {
        Spacer()
        ForEach($errorManager.notifications, id: \.self) { $notification in
          Text(notification)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .foregroundStyle(.white)
            .background(themeColor.color)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 10)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
      }
      .animation(.default, value: errorManager.notifications)
      .padding(.horizontal, 8)
      .padding(.bottom, 64)
      .alert(String(localized: "error.title"), isPresented: $errorManager.hasAlert) {
        Button(String(localized: "common.ok")) {
          ErrorManager.shared.vanishError()
        }
        Button(String(localized: "common.copy")) {
          PlatformHelper.generalPasteboard.string = errorManager.currentError?.description
          ErrorManager.shared.notify(message: String(localized: "notification.copied"))
        }
      } message: {
        if let error = errorManager.currentError {
          Text(verbatim: error.description)
        } else {
          Text(String(localized: "error.unknown"))
        }
      }
    }
  }
#endif
