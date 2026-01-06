//
//  LibraryRowView.swift
//  KMReader
//

import SwiftData
import SwiftUI

struct LibraryRowView: View {
  @AppStorage("isOffline") private var isOffline: Bool = false
  @Bindable var library: KomgaLibrary
  let isSelected: Bool
  let isAdmin: Bool
  let showDeleteAction: Bool
  let onSelect: () -> Void
  let onAction: (LibraryAction) -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(library.name)
            .font(.headline)
          if let fileSize = library.fileSize {
            let fileSizeText = formatFileSize(fileSize)
            Text(fileSizeText)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        if let metricsText = metricsView {
          metricsText
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Spacer()

      Toggle(
        "",
        isOn: Binding(
          get: { isSelected },
          set: { _ in onSelect() }
        )
      )
      .labelsHidden()
    }
    .contentShape(Rectangle())
    .contextMenu {
      if isAdmin {
        ForEach(LibraryAction.allCases, id: \.self) { action in
          Button {
            onAction(action)
          } label: {
            action.label
          }
        }

        if showDeleteAction {
          Divider()

          Button(role: .destructive) {
            onDelete()
          } label: {
            Label(String(localized: "Delete Library"), systemImage: "trash")
          }
        }
      }
    }
  }

  private var metricsView: Text? {
    var parts: [Text] = []

    if let seriesCount = library.seriesCount {
      parts.append(
        formatMetricCount(
          key: "library.list.metrics.series",
          defaultValue: "%lld series",
          value: seriesCount
        ))
    }
    if let booksCount = library.booksCount {
      parts.append(
        formatMetricCount(
          key: "library.list.metrics.books",
          defaultValue: "%lld books",
          value: booksCount
        ))
    }
    if let sidecarsCount = library.sidecarsCount {
      parts.append(
        formatMetricCount(
          key: "library.list.metrics.sidecars",
          defaultValue: "%lld sidecars",
          value: sidecarsCount
        ))
    }

    return joinText(parts, separator: " · ")
  }

  private func formatMetricCount(key: String, defaultValue: String, value: Double) -> Text {
    let format = Bundle.main.localizedString(forKey: key, value: defaultValue, table: nil)
    return Text(String.localizedStringWithFormat(format, Int(value)))
  }

  private func joinText(_ parts: [Text], separator: String) -> Text? {
    guard let first = parts.first else { return nil }
    return parts.dropFirst().reduce(first) { result, part in
      result + Text(separator) + part
    }
  }

  private func formatFileSize(_ bytes: Double) -> String {
    return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary)
  }
}
