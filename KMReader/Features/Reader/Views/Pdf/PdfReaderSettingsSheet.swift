#if os(iOS) || os(macOS)
  import SwiftUI

  struct PdfReaderSettingsSheet: View {
    var body: some View {
      PdfPreferencesView(inSheet: true)
    }
  }
#endif
