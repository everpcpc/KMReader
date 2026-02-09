//
//  NotificationOverlay.swift
//  KMReader
//

import SwiftData
import SwiftUI

#if os(iOS)
  import UIKit

  // Window-based notification manager for displaying notifications above sheets
  @MainActor
  class NotificationWindowManager {
    static let shared = NotificationWindowManager()

    private var notificationWindow: UIWindow?
    private var hostingController: StatusBarObservingHostingController<AnyView>?

    private init() {}

    func setup(
      readerPresentation: ReaderPresentationManager,
      authViewModel: AuthViewModel,
      modelContainer: ModelContainer
    ) {
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

      // Inject all necessary environments into the root view
      let rootView = AnyView(
        NotificationContentView()
          .environment(readerPresentation)
          .environment(authViewModel)
          .modelContainer(modelContainer)
      )

      let hostingController = StatusBarObservingHostingController(
        rootView: rootView,
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

  @MainActor
  private protocol StatusBarObservationHandling: AnyObject {
    func handleObservationChange()
  }

  @MainActor
  private final class WeakStatusBarObserver {
    weak var value: (any StatusBarObservationHandling)?

    init(_ value: any StatusBarObservationHandling) {
      self.value = value
    }
  }

  @MainActor
  private final class StatusBarObservationStore {
    static let shared = StatusBarObservationStore()
    private var observers: [ObjectIdentifier: WeakStatusBarObserver] = [:]

    func register(_ observer: any StatusBarObservationHandling) -> ObjectIdentifier {
      let id = ObjectIdentifier(observer)
      observers[id] = WeakStatusBarObserver(observer)
      return id
    }

    func unregister(_ id: ObjectIdentifier) {
      observers[id] = nil
    }

    func notify(_ id: ObjectIdentifier) {
      observers[id]?.value?.handleObservationChange()
    }
  }

  // A hosting controller that observes ReaderPresentationManager for UI preferences.
  @MainActor
  private class StatusBarObservingHostingController<Content: View>: UIHostingController<Content>,
    StatusBarObservationHandling
  {
    private let readerPresentation: ReaderPresentationManager
    private var observerID: ObjectIdentifier?

    init(rootView: Content, readerPresentation: ReaderPresentationManager) {
      self.readerPresentation = readerPresentation
      super.init(rootView: rootView)
      self.observerID = StatusBarObservationStore.shared.register(self)

      // Observe hideStatusBar changes using withObservationTracking
      startObserving()
    }

    deinit {
      let observerID = observerID
      Task { @MainActor in
        if let observerID {
          StatusBarObservationStore.shared.unregister(observerID)
        }
      }
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    private func startObserving() {
      guard let observerID = observerID else { return }
      withObservationTracking {
        _ = readerPresentation.hideStatusBar
      } onChange: { [observerID] in
        Task { @MainActor in
          StatusBarObservationStore.shared.notify(observerID)
        }
      }
    }

    func handleObservationChange() {
      #if os(iOS)
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
      #endif
      startObserving()
    }

    #if os(iOS)
      override var prefersStatusBarHidden: Bool {
        return readerPresentation.hideStatusBar
      }

      override var prefersHomeIndicatorAutoHidden: Bool {
        return readerPresentation.hideStatusBar
      }
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
      .animation(.snappy, value: errorManager.notifications)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.horizontal, 8)
      .padding(.bottom, 64)
      .alert(String(localized: "error.title"), isPresented: $errorManager.hasAlert) {
        Button(String(localized: "OK")) {
          ErrorManager.shared.vanishError()
        }
        #if os(iOS)
          Button(String(localized: "Copy")) {
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
      .tint(themeColor.color)
    }
  }

  // Modifier to setup the notification window
  struct NotificationWindowSetup: ViewModifier {
    @Environment(ReaderPresentationManager.self) private var readerPresentation
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
      content
        .onAppear {
          NotificationWindowManager.shared.setup(
            readerPresentation: readerPresentation,
            authViewModel: authViewModel,
            modelContainer: modelContext.container
          )
        }
    }
  }

  extension View {
    func setupNotificationWindow() -> some View {
      modifier(NotificationWindowSetup())
    }
  }

#elseif os(tvOS)
  // Keep alerts in the main view hierarchy so tvOS focus reliably lands on alert actions.
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
      .animation(.snappy, value: errorManager.notifications)
      .padding(.horizontal, 8)
      .padding(.bottom, 64)
      .alert(String(localized: "error.title"), isPresented: $errorManager.hasAlert) {
        Button(String(localized: "OK")) {
          ErrorManager.shared.vanishError()
        }
      } message: {
        if let error = errorManager.currentError {
          Text(verbatim: error.description)
        } else {
          Text(String(localized: "error.unknown"))
        }
      }
      .tint(themeColor.color)
      .onExitCommand {
        guard errorManager.hasAlert else { return }
        ErrorManager.shared.vanishError()
      }
    }
  }

#elseif os(macOS)
  // macOS uses regular overlay approach since sheets behave differently
  struct NotificationOverlay: View {
    @State private var errorManager = ErrorManager.shared

    var body: some View {
      VStack(alignment: .center) {
        Spacer()
        ForEach($errorManager.notifications, id: \.self) { $notification in
          Text(notification)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .foregroundStyle(.white)
            .background(Color.accentColor)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 10)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
      }
      .animation(.default, value: errorManager.notifications)
      .padding(.horizontal, 8)
      .padding(.bottom, 64)
      .alert(String(localized: "error.title"), isPresented: $errorManager.hasAlert) {
        Button(String(localized: "OK")) {
          ErrorManager.shared.vanishError()
        }
        Button(String(localized: "Copy")) {
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
