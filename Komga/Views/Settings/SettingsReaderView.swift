//
//  SettingsReaderView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsReaderView: View {
  @AppStorage("showTapZone") private var showTapZone: Bool = true
  @AppStorage("readerBackground") private var readerBackground: ReaderBackground =
    .black
  @AppStorage("webtoonPageWidthPercentage") private var webtoonPageWidthPercentage: Double = 100.0

  var body: some View {
    Form {
      Section(header: Text("Tap Zone")) {
        Toggle(isOn: $showTapZone) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Show Tap Zone Hints")
            Text("Display tap zone hints when entering reader")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }

      Section(header: Text("Background")) {
        VStack(alignment: .leading, spacing: 8) {
          Picker("Reader Background", selection: $readerBackground) {
            ForEach(ReaderBackground.allCases, id: \.self) { background in
              Text(background.displayName).tag(background)
            }
          }
          .pickerStyle(.menu)
          Text("The background color of the reader")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Section(header: Text("Webtoon")) {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Page Width")
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
        }
      }
    }
    .navigationTitle("Reader")
    .navigationBarTitleDisplayMode(.inline)
  }
}
