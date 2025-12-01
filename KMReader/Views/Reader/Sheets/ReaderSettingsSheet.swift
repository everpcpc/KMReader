//
//  ReaderSettingsSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReaderSettingsSheet: View {
  @Binding var readingDirection: ReadingDirection
  @Binding var readerBackground: ReaderBackground
  @Binding var pageLayout: PageLayout
  @Binding var dualPageNoCover: Bool
  @Binding var webtoonPageWidthPercentage: Double

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          cardSection(title: "Read Mode") {
            Picker("Read Mode", selection: $readingDirection) {
              ForEach(ReadingDirection.availableCases, id: \.self) { direction in
                Text(direction.displayName)
                  .tag(direction)
              }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
          }

          cardSection(title: "Background") {
            Picker("", selection: $readerBackground) {
              ForEach(ReaderBackground.allCases, id: \.self) { background in
                Text(background.displayName)
                  .tag(background)
              }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
          }

          switch readingDirection {
          case .webtoon:
            webtoonSection
          default:
            layoutSection
          }
        }
        .padding(24)
      }
      .inlineNavigationBarTitle("Reader Settings")
    }
    .presentationDragIndicator(.visible)
    .platformSheetPresentation(detents: [.large])
  }

  private func cardSection<Content: View>(
    title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline)
        .lineLimit(nil)
      content()
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial)
    .cornerRadius(20)
    .focusSectionIfAvailable()
  }

  private var layoutSection: some View {
    cardSection(title: "Page Layout") {
      Picker("", selection: $pageLayout) {
        ForEach(PageLayout.allCases, id: \.self) { layout in
          Text(layout.displayName)
            .tag(layout)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      if pageLayout == .dual {
        Toggle(isOn: $dualPageNoCover) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Show Cover in Dual Spread")
              .lineLimit(nil)
              .multilineTextAlignment(.leading)
            Text("Display the cover alongside the next page instead of on its own")
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(nil)
              .multilineTextAlignment(.leading)
          }
        }
      }
    }
  }

  private var webtoonSection: some View {
    cardSection(title: "Webtoon") {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("Page Width")
          Spacer()
          Text("\(Int(webtoonPageWidthPercentage))%")
            .foregroundColor(.secondary)
        }
        HStack(spacing: 32) {
          Button {
            webtoonPageWidthPercentage = max(50, webtoonPageWidthPercentage - 5)
          } label: {
            Image(systemName: "minus.circle")
              .font(.title)
          }
          Button {
            webtoonPageWidthPercentage = min(100, webtoonPageWidthPercentage + 5)
          } label: {
            Image(systemName: "plus.circle")
              .font(.title)
          }
        }
        Text("Adjust the width of pages when reading in webtoon mode")
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(nil)
          .multilineTextAlignment(.leading)
      }
    }
  }

}

extension View {
  @ViewBuilder
  fileprivate func focusSectionIfAvailable() -> some View {
    #if os(tvOS)
      self.focusSection()
    #else
      self
    #endif
  }
}
