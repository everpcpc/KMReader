//
//  SeriesEditSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SeriesEditSheet: View {
  let series: Series
  @Environment(\.dismiss) private var dismiss
  @State private var isSaving = false

  // Series metadata fields
  @State private var title: String
  @State private var titleSort: String
  @State private var summary: String
  @State private var publisher: String
  @State private var ageRating: String
  @State private var language: String
  @State private var readingDirection: ReadingDirection
  @State private var status: SeriesStatus
  @State private var genres: [String]
  @State private var tags: [String]
  @State private var links: [WebLink]
  @State private var alternateTitles: [AlternateTitle]

  @State private var newGenre: String = ""
  @State private var newTag: String = ""
  @State private var newLinkLabel: String = ""
  @State private var newLinkURL: String = ""
  @State private var newAlternateTitleLabel: String = ""
  @State private var newAlternateTitle: String = ""

  init(series: Series) {
    self.series = series
    _title = State(initialValue: series.metadata.title)
    _titleSort = State(initialValue: series.metadata.titleSort)
    _summary = State(initialValue: series.metadata.summary ?? "")
    _publisher = State(initialValue: series.metadata.publisher ?? "")
    _ageRating = State(initialValue: series.metadata.ageRating.map { String($0) } ?? "")
    _language = State(initialValue: series.metadata.language ?? "")
    _readingDirection = State(
      initialValue: ReadingDirection.fromString(series.metadata.readingDirection)
    )
    _status = State(
      initialValue: SeriesStatus.fromString(series.metadata.status))
    _genres = State(initialValue: series.metadata.genres ?? [])
    _tags = State(initialValue: series.metadata.tags ?? [])
    _links = State(initialValue: series.metadata.links ?? [])
    _alternateTitles = State(initialValue: series.metadata.alternateTitles ?? [])
  }

  var body: some View {
    SheetView(title: "Edit Series", size: .large) {
        Form {
        Section("Basic Information") {
          TextField("Title", text: $title)
          TextField("Title Sort", text: $titleSort)
          TextField("Summary", text: $summary, axis: .vertical)
            .lineLimit(3...10)
          TextField("Publisher", text: $publisher)
          TextField("Age Rating", text: $ageRating)
            #if os(iOS) || os(tvOS)
              .keyboardType(.numberPad)
            #endif
          TextField("Language", text: $language)
          Picker("Reading Direction", selection: $readingDirection) {
            ForEach(ReadingDirection.allCases, id: \.self) { direction in
              Text(direction.displayName).tag(direction)
            }
          }
          Picker("Status", selection: $status) {
            ForEach(SeriesStatus.allCases, id: \.self) { status in
              Text(status.displayName).tag(status)
            }
          }
        }

        Section("Genres") {
          ForEach(genres.indices, id: \.self) { index in
            HStack {
              Text(genres[index])
              Spacer()
              Button(role: .destructive) {
                genres.remove(at: index)
              } label: {
                Image(systemName: "trash")
              }
            }
          }
          HStack {
            TextField("Genre", text: $newGenre)
            Button {
              if !newGenre.isEmpty && !genres.contains(newGenre) {
                genres.append(newGenre)
                newGenre = ""
              }
            } label: {
              Image(systemName: "plus.circle.fill")
            }
            .disabled(newGenre.isEmpty)
          }
        }

        Section("Tags") {
          ForEach(tags.indices, id: \.self) { index in
            HStack {
              Text(tags[index])
              Spacer()
              Button(role: .destructive) {
                tags.remove(at: index)
              } label: {
                Image(systemName: "trash")
              }
            }
          }
          HStack {
            TextField("Tag", text: $newTag)
            Button {
              if !newTag.isEmpty && !tags.contains(newTag) {
                tags.append(newTag)
                newTag = ""
              }
            } label: {
              Image(systemName: "plus.circle.fill")
            }
            .disabled(newTag.isEmpty)
          }
        }

        Section("Links") {
          ForEach(links.indices, id: \.self) { index in
            VStack(alignment: .leading) {
              HStack {
                Text(links[index].label)
                  .font(.body)
                Spacer()
                Button(role: .destructive) {
                  links.remove(at: index)
                } label: {
                  Image(systemName: "trash")
                }
              }
              Text(links[index].url)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          VStack {
            TextField("Label", text: $newLinkLabel)
            TextField("URL", text: $newLinkURL)
              #if os(iOS) || os(tvOS)
                .keyboardType(.URL)
                .autocapitalization(.none)
              #endif
            Button {
              if !newLinkLabel.isEmpty && !newLinkURL.isEmpty {
                links.append(WebLink(label: newLinkLabel, url: newLinkURL))
                newLinkLabel = ""
                newLinkURL = ""
              }
            } label: {
              Label("Add Link", systemImage: "plus.circle.fill")
            }
            .disabled(newLinkLabel.isEmpty || newLinkURL.isEmpty)
          }
        }

        Section("Alternate Titles") {
          ForEach(alternateTitles.indices, id: \.self) { index in
            VStack(alignment: .leading) {
              HStack {
                Text(alternateTitles[index].label)
                  .font(.body)
                Spacer()
                Button(role: .destructive) {
                  alternateTitles.remove(at: index)
                } label: {
                  Image(systemName: "trash")
                }
              }
              Text(alternateTitles[index].title)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          VStack {
            TextField("Label", text: $newAlternateTitleLabel)
            TextField("Title", text: $newAlternateTitle)
            Button {
              if !newAlternateTitleLabel.isEmpty && !newAlternateTitle.isEmpty {
                alternateTitles.append(
                  AlternateTitle(label: newAlternateTitleLabel, title: newAlternateTitle))
                newAlternateTitleLabel = ""
                newAlternateTitle = ""
              }
            } label: {
              Label("Add Alternate Title", systemImage: "plus.circle.fill")
            }
            .disabled(newAlternateTitleLabel.isEmpty || newAlternateTitle.isEmpty)
          }
        }
        }
      }
    controls: {
      Button(action: saveChanges) {
        if isSaving {
          ProgressView()
        } else {
          Label("Save", systemImage: "checkmark")
        }
      }
      .disabled(isSaving)
    }
  }

  private func saveChanges() {
    isSaving = true
    Task {
      do {
        var metadata: [String: Any] = [:]

        if title != series.metadata.title {
          metadata["title"] = title
        }
        if titleSort != series.metadata.titleSort {
          metadata["titleSort"] = titleSort
        }
        if summary != (series.metadata.summary ?? "") {
          metadata["summary"] = summary.isEmpty ? NSNull() : summary
        }
        if publisher != (series.metadata.publisher ?? "") {
          metadata["publisher"] = publisher.isEmpty ? NSNull() : publisher
        }
        if let ageRatingInt = Int(ageRating), ageRatingInt != (series.metadata.ageRating ?? 0) {
          metadata["ageRating"] = ageRating.isEmpty ? NSNull() : ageRatingInt
        } else if ageRating.isEmpty && series.metadata.ageRating != nil {
          metadata["ageRating"] = NSNull()
        }
        if language != (series.metadata.language ?? "") {
          metadata["language"] = language.isEmpty ? NSNull() : language
        }
        let currentReadingDirection = ReadingDirection.fromString(
          series.metadata.readingDirection ?? "LEFT_TO_RIGHT")
        if readingDirection != currentReadingDirection {
          metadata["readingDirection"] = readingDirection.rawValue
        }
        let currentStatus = SeriesStatus.fromString(series.metadata.status)
        if status != currentStatus {
          metadata["status"] = status.apiValue
        }

        let currentGenres = series.metadata.genres ?? []
        if genres != currentGenres {
          metadata["genres"] = genres
        }

        let currentTags = series.metadata.tags ?? []
        if tags != currentTags {
          metadata["tags"] = tags
        }

        let currentLinks = series.metadata.links ?? []
        if links != currentLinks {
          metadata["links"] = links.map { ["label": $0.label, "url": $0.url] }
        }

        let currentAlternateTitles = series.metadata.alternateTitles ?? []
        if alternateTitles != currentAlternateTitles {
          metadata["alternateTitles"] = alternateTitles.map {
            ["label": $0.label, "title": $0.title]
          }
        }

        if !metadata.isEmpty {
          try await SeriesService.shared.updateSeriesMetadata(
            seriesId: series.id, metadata: metadata)
          await MainActor.run {
            ErrorManager.shared.notify(message: "Series updated")
            dismiss()
          }
        } else {
          await MainActor.run {
            dismiss()
          }
        }
      } catch {
        await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      await MainActor.run {
        isSaving = false
      }
    }
  }
}
