//
//  LibraryRowView.swift
//  KMReader
//

import SwiftData
import SwiftUI

struct LibraryRowView: View {
  @Environment(KomgaLibrary.self) private var library
  let isPerforming: Bool
  let isSelected: Bool
  let isAdmin: Bool
  let showDeleteAction: Bool
  let onSelect: () -> Void
  let onAction: (LibraryAction) -> Void
  let onDelete: () -> Void

  enum LibraryAction {
    case scan
    case scanDeep
    case analyze
    case refreshMetadata
    case emptyTrash
  }

  var body: some View {
    Button {
      onSelect()
    } label: {
      librarySummary
        .contentShape(Rectangle())
    }
    .adaptiveButtonStyle(.plain)
    #if os(iOS) || os(macOS)
      .listRowSeparator(.hidden)
    #endif
    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
    .contextMenu {
      if isAdmin {
        Button {
          onAction(.scan)
        } label: {
          Label(String(localized: "Scan Library Files"), systemImage: "arrow.clockwise")
        }
        .disabled(isPerforming)

        Button {
          onAction(.scanDeep)
        } label: {
          Label(
            String(localized: "Scan Library Files (Deep)"),
            systemImage: "arrow.triangle.2.circlepath"
          )
        }
        .disabled(isPerforming)

        Button {
          onAction(.analyze)
        } label: {
          Label(String(localized: "Analyze"), systemImage: "waveform.path.ecg")
        }
        .disabled(isPerforming)

        Button {
          onAction(.refreshMetadata)
        } label: {
          Label(String(localized: "Refresh Metadata"), systemImage: "arrow.triangle.branch")
        }
        .disabled(isPerforming)

        Button {
          onAction(.emptyTrash)
        } label: {
          Label(String(localized: "Empty Trash"), systemImage: "trash.slash")
        }
        .disabled(isPerforming)

        if showDeleteAction {
          Divider()

          Button(role: .destructive) {
            onDelete()
          } label: {
            Label(String(localized: "Delete Library"), systemImage: "trash")
          }
          .disabled(isPerforming)
        }
      }
    }
  }

  @ViewBuilder
  private var librarySummary: some View {
    let fileSizeText = library.fileSize.map { formatFileSize($0) } ?? ""
    let metricsText = metricsView

    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(library.name)
            .font(.headline)
          if !fileSizeText.isEmpty {
            Text(fileSizeText)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        if let metricsText {
          metricsText
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Spacer()

      if isPerforming {
        ProgressView()
          .progressViewStyle(.circular)
      } else if isSelected {
        Image(systemName: "checkmark.circle.fill")
          .font(.title3)
          .foregroundColor(.accentColor)
          .transition(.scale.combined(with: .opacity))
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.06))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(
          isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
          lineWidth: 1.5
        )
    )
    .animation(.easeInOut(duration: 0.2), value: isSelected)
  }

  private var metricsView: Text? {
    var parts: [Text] = []

    if let seriesCount = library.seriesCount {
      parts.append(
        formatMetricCount(
          key: "library.list.metrics.series",
          defaultValue: "%@ series",
          value: seriesCount
        ))
    }
    if let booksCount = library.booksCount {
      parts.append(
        formatMetricCount(
          key: "library.list.metrics.books",
          defaultValue: "%@ books",
          value: booksCount
        ))
    }
    if let sidecarsCount = library.sidecarsCount {
      parts.append(
        formatMetricCount(
          key: "library.list.metrics.sidecars",
          defaultValue: "%@ sidecars",
          value: sidecarsCount
        ))
    }

    return joinText(parts, separator: " · ")
  }

  private func formatNumber(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
  }

  private func formatMetricCount(key: String, defaultValue: String, value: Double) -> Text {
    let format = Bundle.main.localizedString(forKey: key, value: defaultValue, table: nil)
    return Text(String.localizedStringWithFormat(format, formatNumber(value)))
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
