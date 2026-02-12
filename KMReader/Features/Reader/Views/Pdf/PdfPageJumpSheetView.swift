#if os(iOS) || os(macOS)
  import SwiftUI

  struct PdfPageJumpSheetView: View {
    let totalPages: Int
    let currentPage: Int
    let onJump: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var pageValue: Int

    private var maxPage: Int {
      max(totalPages, 1)
    }

    private var canJump: Bool {
      totalPages > 0
    }

    private var sliderBinding: Binding<Double> {
      Binding(
        get: { Double(pageValue) },
        set: { newValue in
          pageValue = Int(newValue.rounded())
        }
      )
    }

    init(totalPages: Int, currentPage: Int, onJump: @escaping (Int) -> Void) {
      self.totalPages = totalPages
      self.currentPage = currentPage
      self.onJump = onJump
      _pageValue = State(initialValue: max(1, min(currentPage, max(totalPages, 1))))
    }

    private func jumpToPage() {
      guard canJump else { return }
      let target = max(1, min(pageValue, totalPages))
      onJump(target)
      dismiss()
    }

    var body: some View {
      SheetView(title: String(localized: "Go to Page"), size: .medium) {
        VStack(spacing: 20) {
          Text("Current page: \(currentPage)")
            .foregroundStyle(.secondary)

          if canJump {
            Text("\(pageValue)")
              .font(.system(size: 44, weight: .bold, design: .rounded))
              .monospacedDigit()

            Slider(value: sliderBinding, in: 1...Double(maxPage), step: 1)

            HStack {
              Text("1")
              Spacer()
              Text("\(totalPages)")
            }
            .foregroundStyle(.secondary)

            Button {
              jumpToPage()
            } label: {
              Label("Jump", systemImage: "arrow.right.to.line")
            }
            .adaptiveButtonStyle(.borderedProminent)
            .disabled(pageValue == currentPage)
          } else {
            Text(String(localized: "No pages available."))
              .foregroundStyle(.secondary)
          }

          Spacer()
        }
        .padding()
      }
      .presentationDragIndicator(.visible)
    }
  }
#endif
