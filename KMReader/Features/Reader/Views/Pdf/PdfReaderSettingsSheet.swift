#if os(iOS) || os(macOS)
  import SwiftUI

  struct PdfReaderSettingsSheet: View {
    @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system
    @AppStorage("readerControlsGradientBackground") private var readerControlsGradientBackground: Bool = false
    @AppStorage("defaultReadingDirection") private var defaultReadingDirection: ReadingDirection = .ltr
    @AppStorage("forceDefaultReadingDirection") private var forceDefaultReadingDirection: Bool = false
    @AppStorage("pageLayout") private var pageLayout: PageLayout = .auto
    @AppStorage("isolateCoverPage") private var isolateCoverPage: Bool = true

    var body: some View {
      SheetView(
        title: String(localized: "Reader Settings"),
        size: .medium,
        applyFormStyle: true
      ) {
        Form {
          Section(header: Text("Appearance")) {
            Picker("Reader Background", selection: $readerBackground) {
              ForEach(ReaderBackground.allCases, id: \.self) { background in
                Text(background.displayName).tag(background)
              }
            }
            .pickerStyle(.menu)

            Toggle(isOn: $readerControlsGradientBackground) {
              Text("Controls Gradient Background")
            }
          }

          Section(header: Text("Default Reading Options")) {
            VStack(alignment: .leading, spacing: 8) {
              Picker("Preferred Direction", selection: $defaultReadingDirection) {
                ForEach(ReadingDirection.availableCases, id: \.self) { direction in
                  Label(direction.displayName, systemImage: direction.icon)
                    .tag(direction)
                }
              }
              .pickerStyle(.menu)

              Text("Used when a book or series doesn't specify a reading direction")
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Toggle(isOn: $forceDefaultReadingDirection) {
              VStack(alignment: .leading, spacing: 4) {
                Text("Force Default Reading Direction")
                Text("Ignore book and series metadata and always use the preferred direction")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }

            VStack(alignment: .leading, spacing: 8) {
              Picker("Page Layout", selection: $pageLayout) {
                ForEach(PageLayout.allCases, id: \.self) { layout in
                  Label(layout.displayName, systemImage: layout.icon)
                    .tag(layout)
                }
              }
              .pickerStyle(.menu)

              Text("Used for single and dual-page presentation in paged or continuous mode")
                .font(.caption)
                .foregroundColor(.secondary)
            }

            if pageLayout.supportsDualPageOptions {
              Toggle(isOn: $isolateCoverPage) {
                VStack(alignment: .leading, spacing: 4) {
                  Text("Isolate Cover Page")
                  Text("Show the first page alone before entering dual-page spread")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
            }
          }

        }
      }
      .presentationDragIndicator(.visible)
    }
  }
#endif
