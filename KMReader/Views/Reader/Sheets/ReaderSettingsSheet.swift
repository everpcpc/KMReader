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
    SheetView(title: "Reader Settings", size: .medium, applyFormStyle: true) {
      Form {
        Section(header: Text("Appearance")) {
          Picker("Reader Background", selection: $readerBackground) {
            ForEach(ReaderBackground.allCases, id: \.self) { background in
              Text(background.displayName).tag(background)
            }
          }
          .pickerStyle(.menu)
        }

        Section(header: Text("Reading Options")) {
          Picker("Reading Direction", selection: $readingDirection) {
            ForEach(ReadingDirection.availableCases, id: \.self) { direction in
              Label(direction.displayName, systemImage: direction.icon)
                .tag(direction)
            }
          }
          .pickerStyle(.menu)

          switch readingDirection {
          case .webtoon:
            webtoonSection
          case .vertical:
            pageNumberSection
          default:
            layoutSection
            pageNumberSection
          }
        }
      }
    }
    .presentationDragIndicator(.visible)
  }

  private var layoutSection: some View {
    Group {
      Picker("Layout Mode", selection: $pageLayout) {
        ForEach(PageLayout.allCases, id: \.self) { layout in
          Label(layout.displayName, systemImage: layout.icon)
            .tag(layout)
        }
      }.pickerStyle(.menu)

      if pageLayout.supportsDualPageOptions {
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
    #if os(iOS)
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Webtoon Page Width")
          Spacer()
          Text("\(Int(webtoonPageWidthPercentage))%")
            .foregroundColor(.secondary)
        }
        Slider(
          value: $webtoonPageWidthPercentage,
          in: 50...100,
          step: 5
        )
        Text("Adjust the width of webtoon pages as a percentage of screen width")
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(nil)
          .multilineTextAlignment(.leading)
      }
    #else
      EmptyView()
    #endif
  }

  @AppStorage("showPageNumber") private var showPageNumber: Bool = true

  private var pageNumberSection: some View {
    Toggle(isOn: $showPageNumber) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Always Show Page Number")
          .lineLimit(nil)
          .multilineTextAlignment(.leading)
        Text("Display page number overlay on images while reading")
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(nil)
          .multilineTextAlignment(.leading)
      }
    }
  }
}
