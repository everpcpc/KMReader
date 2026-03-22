//
// KeyboardEventHandler.swift
//
//

import SwiftUI

#if os(macOS)
  import AppKit

  // Window-level keyboard event handler
  struct KeyboardEventHandler: NSViewRepresentable {
    let onKeyPress: (UInt16, NSEvent.ModifierFlags) -> Bool

    func makeNSView(context: Context) -> KeyboardHandlerView {
      let view = KeyboardHandlerView()
      view.onKeyPress = onKeyPress
      return view
    }

    func updateNSView(_ nsView: KeyboardHandlerView, context: Context) {
      nsView.onKeyPress = onKeyPress
    }
  }

  class KeyboardHandlerView: NSView {
    var onKeyPress: ((UInt16, NSEvent.ModifierFlags) -> Bool)?
    private var keyMonitor: Any?

    override var acceptsFirstResponder: Bool {
      return true
    }

    override func becomeFirstResponder() -> Bool {
      return true
    }

    override func keyDown(with event: NSEvent) {
      let handled = onKeyPress?(event.keyCode, event.modifierFlags) ?? false
      if !handled {
        super.keyDown(with: event)
      }
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      // Make this view the first responder when added to window
      DispatchQueue.main.async { [weak self] in
        self?.window?.makeFirstResponder(self)
      }
      installMonitorIfNeeded()
    }

    override func removeFromSuperview() {
      super.removeFromSuperview()
      teardownMonitor()
    }

    // Don't intercept mouse events - let them pass through
    override func hitTest(_ point: NSPoint) -> NSView? {
      return nil
    }

    private func installMonitorIfNeeded() {
      guard keyMonitor == nil else { return }
      keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        guard let self, let window = self.window, window.isKeyWindow else { return event }
        let handled = self.onKeyPress?(event.keyCode, event.modifierFlags) ?? false
        return handled ? nil : event
      }
    }

    private func teardownMonitor() {
      guard let keyMonitor else { return }
      NSEvent.removeMonitor(keyMonitor)
      self.keyMonitor = nil
    }
  }
#endif
