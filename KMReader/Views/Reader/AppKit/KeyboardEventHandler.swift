//
//  KeyboardEventHandler.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

#if os(macOS)
  import AppKit

  // Window-level keyboard event handler
  struct KeyboardEventHandler: NSViewRepresentable {
    let onKeyPress: (UInt16, NSEvent.ModifierFlags) -> Void

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
    var onKeyPress: ((UInt16, NSEvent.ModifierFlags) -> Void)?

    override var acceptsFirstResponder: Bool {
      return true
    }

    override func becomeFirstResponder() -> Bool {
      return true
    }

    override func keyDown(with event: NSEvent) {
      onKeyPress?(event.keyCode, event.modifierFlags)
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      // Make this view the first responder when added to window
      DispatchQueue.main.async { [weak self] in
        self?.window?.makeFirstResponder(self)
      }
    }

    // Don't intercept mouse events - let them pass through
    override func hitTest(_ point: NSPoint) -> NSView? {
      return nil
    }
  }
#endif
