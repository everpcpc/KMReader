//
// PageHashMatchesView.swift
//
//

import SwiftUI

struct PageHashMatchesView: View {
  let hash: String

  @State private var matches: [PageHashMatch] = []
  @State private var isLoading = false

  var body: some View {
    Form {
      if isLoading {
        Section {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
        }
      } else if matches.isEmpty {
        Section {
          Text(String(localized: "No matches found"))
            .foregroundColor(.secondary)
        }
      } else {
        Section {
          ForEach(matches) { match in
            matchRow(match: match)
          }
        }
      }
    }
    .task {
      await loadMatches()
    }
  }

  @ViewBuilder
  private func matchRow(match: PageHashMatch) -> some View {
    HStack(spacing: 12) {
      // Page thumbnail
      if let url = BookService.shared.getBookPageThumbnailURL(
        bookId: match.bookId, page: match.pageNumber)
      {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 50, height: 70)
              .clipShape(RoundedRectangle(cornerRadius: 4))
          case .failure:
            placeholderImage
          default:
            ProgressView()
              .frame(width: 50, height: 70)
          }
        }
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(match.fileName)
          .lineLimit(1)

        Text(match.url)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(2)

        HStack(spacing: 12) {
          Label(
            String(localized: "Page \(match.pageNumber)"),
            systemImage: "doc"
          )
          .font(.caption)
          .foregroundColor(.secondary)

          Text(match.mediaType)
            .font(.caption)
            .foregroundColor(.secondary)

          Text(
            ByteCountFormatter.string(
              fromByteCount: match.fileSize, countStyle: .binary)
          )
          .font(.caption)
          .foregroundColor(.secondary)
        }
      }

      Spacer()

      Button(role: .destructive) {
        Task { await deleteMatch(match) }
      } label: {
        Image(systemName: "trash")
          .foregroundColor(.red)
      }
      .buttonStyle(.borderless)
    }
  }

  private var placeholderImage: some View {
    RoundedRectangle(cornerRadius: 4)
      .fill(.secondary.opacity(0.2))
      .frame(width: 50, height: 70)
      .overlay {
        Image(systemName: "photo")
          .foregroundColor(.secondary)
      }
  }

  private func deleteMatch(_ match: PageHashMatch) async {
    do {
      try await MediaManagementService.shared.deleteMatchByHash(hash, match: match)
      matches.removeAll { $0.id == match.id }
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  private func loadMatches() async {
    isLoading = true
    do {
      let page = try await MediaManagementService.shared.getPageHashMatches(
        hash: hash,
        page: 0,
        size: 100
      )
      matches = page.content
    } catch {
      ErrorManager.shared.alert(error: error)
    }
    isLoading = false
  }
}
