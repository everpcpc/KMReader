//
// AppViewContext.swift
//
//

import Foundation

struct AppViewContext {
  let authViewModel: AuthViewModel
  let readerPresentation: ReaderPresentationManager

  var readerActions: ReaderActions {
    .live(readerPresentation: readerPresentation)
  }
}
