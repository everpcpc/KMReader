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
  @State private var titleLock: Bool
  @State private var titleSort: String
  @State private var titleSortLock: Bool
  @State private var summary: String
  @State private var summaryLock: Bool
  @State private var publisher: String
  @State private var publisherLock: Bool
  @State private var ageRating: String
  @State private var ageRatingLock: Bool
  @State private var totalBookCount: String
  @State private var totalBookCountLock: Bool
  @State private var language: String
  @State private var languageLock: Bool
  @State private var readingDirection: ReadingDirection
  @State private var readingDirectionLock: Bool
  @State private var status: SeriesStatus
  @State private var statusLock: Bool
  @State private var genres: [String]
  @State private var genresLock: Bool
  @State private var tags: [String]
  @State private var tagsLock: Bool
  @State private var links: [WebLink]
  @State private var linksLock: Bool
  @State private var alternateTitles: [AlternateTitle]
  @State private var alternateTitlesLock: Bool

  @State private var newGenre: String = ""
  @State private var newTag: String = ""
  @State private var newLinkLabel: String = ""
  @State private var newLinkURL: String = ""
  @State private var newAlternateTitleLabel: String = ""
  @State private var newAlternateTitle: String = ""

  init(series: Series) {
    self.series = series
    _title = State(initialValue: series.metadata.title)
    _titleLock = State(initialValue: series.metadata.titleLock ?? false)
    _titleSort = State(initialValue: series.metadata.titleSort)
    _titleSortLock = State(initialValue: series.metadata.titleSortLock ?? false)
    _summary = State(initialValue: series.metadata.summary ?? "")
    _summaryLock = State(initialValue: series.metadata.summaryLock ?? false)
    _publisher = State(initialValue: series.metadata.publisher ?? "")
    _publisherLock = State(initialValue: series.metadata.publisherLock ?? false)
    _ageRating = State(initialValue: series.metadata.ageRating.map { String($0) } ?? "")
    _ageRatingLock = State(initialValue: series.metadata.ageRatingLock ?? false)
    _totalBookCount = State(initialValue: series.metadata.totalBookCount.map { String($0) } ?? "")
    _totalBookCountLock = State(initialValue: series.metadata.totalBookCountLock ?? false)
    _language = State(initialValue: series.metadata.language ?? "")
    _languageLock = State(initialValue: series.metadata.languageLock ?? false)
    _readingDirection = State(
      initialValue: ReadingDirection.fromString(series.metadata.readingDirection)
    )
    _readingDirectionLock = State(initialValue: series.metadata.readingDirectionLock ?? false)
    _status = State(
      initialValue: SeriesStatus.fromString(series.metadata.status))
    _statusLock = State(initialValue: series.metadata.statusLock ?? false)
    _genres = State(initialValue: series.metadata.genres ?? [])
    _genresLock = State(initialValue: series.metadata.genresLock ?? false)
    _tags = State(initialValue: series.metadata.tags ?? [])
    _tagsLock = State(initialValue: series.metadata.tagsLock ?? false)
    _links = State(initialValue: series.metadata.links ?? [])
    _linksLock = State(initialValue: series.metadata.linksLock ?? false)
    _alternateTitles = State(initialValue: series.metadata.alternateTitles ?? [])
    _alternateTitlesLock = State(initialValue: series.metadata.alternateTitlesLock ?? false)
  }

  var body: some View {
    SheetView(title: String(localized: "Edit Series"), size: .large, applyFormStyle: true) {
      Form {
        Section("Basic Information") {
          TextField("Title", text: $title)
            .lockToggle(isLocked: $titleLock)
            .onChange(of: title) { titleLock = true }
          TextField("Title Sort", text: $titleSort)
            .lockToggle(isLocked: $titleSortLock)
            .onChange(of: titleSort) { titleSortLock = true }
          TextField("Total Book Count", text: $totalBookCount)
            #if os(iOS) || os(tvOS)
              .keyboardType(.numberPad)
            #endif
            .lockToggle(isLocked: $totalBookCountLock)
            .onChange(of: totalBookCount) { totalBookCountLock = true }
          TextField("Summary", text: $summary, axis: .vertical)
            .lineLimit(3...10)
            .lockToggle(isLocked: $summaryLock)
            .onChange(of: summary) { summaryLock = true }
          Picker("Status", selection: $status) {
            ForEach(SeriesStatus.allCases, id: \.self) { status in
              Text(status.displayName).tag(status)
            }
          }
          .lockToggle(isLocked: $statusLock)
          .onChange(of: status) { statusLock = true }
          LanguagePicker(selectedLanguage: $language)
            .lockToggle(isLocked: $languageLock)
            .onChange(of: language) { languageLock = true }
          Picker("Reading Direction", selection: $readingDirection) {
            ForEach(ReadingDirection.allCases, id: \.self) { direction in
              Text(direction.displayName).tag(direction)
            }
          }
          .lockToggle(isLocked: $readingDirectionLock)
          .onChange(of: readingDirection) { readingDirectionLock = true }
          TextField("Publisher", text: $publisher)
            .lockToggle(isLocked: $publisherLock)
            .onChange(of: publisher) { publisherLock = true }
          TextField("Age Rating", text: $ageRating)
            #if os(iOS) || os(tvOS)
              .keyboardType(.numberPad)
            #endif
            .lockToggle(isLocked: $ageRatingLock)
            .onChange(of: ageRating) { ageRatingLock = true }
        }

        Section {
          ForEach(alternateTitles.indices, id: \.self) { index in
            VStack(alignment: .leading) {
              HStack {
                Text(alternateTitles[index].label)
                  .font(.body)
                Spacer()
                Button(role: .destructive) {
                  let indexToRemove = index
                  withAnimation {
                    alternateTitles.remove(at: indexToRemove)
                    alternateTitlesLock = true
                  }
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
                withAnimation {
                  alternateTitles.append(
                    AlternateTitle(label: newAlternateTitleLabel, title: newAlternateTitle))
                  newAlternateTitleLabel = ""
                  newAlternateTitle = ""
                  alternateTitlesLock = true
                }
              }
            } label: {
              Label("Add Alternate Title", systemImage: "plus.circle.fill")
            }
            .disabled(newAlternateTitleLabel.isEmpty || newAlternateTitle.isEmpty)
          }
        } header: {
          HStack {
            Button(action: { alternateTitlesLock.toggle() }) {
              Image(systemName: alternateTitlesLock ? "lock.fill" : "lock.open.fill")
                .foregroundColor(alternateTitlesLock ? .secondary : .gray)
            }
            .adaptiveButtonStyle(.plain)
            Text("Alternate Titles")
            Spacer()
          }
        }

        Section {
          ForEach(genres.indices, id: \.self) { index in
            HStack {
              Text(genres[index])
              Spacer()
              Button(role: .destructive) {
                let indexToRemove = index
                withAnimation {
                  genres.remove(at: indexToRemove)
                  genresLock = true
                }
              } label: {
                Image(systemName: "trash")
              }
            }
          }
          HStack {
            TextField("Genre", text: $newGenre)
            Button {
              if !newGenre.isEmpty && !genres.contains(newGenre) {
                withAnimation {
                  genres.append(newGenre)
                  newGenre = ""
                  genresLock = true
                }
              }
            } label: {
              Image(systemName: "plus.circle.fill")
            }
            .disabled(newGenre.isEmpty)
          }
        } header: {
          Text("Genres")
            .lockToggle(isLocked: $genresLock)
        }

        Section {
          ForEach(tags.indices, id: \.self) { index in
            HStack {
              Text(tags[index])
              Spacer()
              Button(role: .destructive) {
                let indexToRemove = index
                withAnimation {
                  tags.remove(at: indexToRemove)
                  tagsLock = true
                }
              } label: {
                Image(systemName: "trash")
              }
            }
          }
          HStack {
            TextField("Tag", text: $newTag)
            Button {
              if !newTag.isEmpty && !tags.contains(newTag) {
                withAnimation {
                  tags.append(newTag)
                  newTag = ""
                  tagsLock = true
                }
              }
            } label: {
              Image(systemName: "plus.circle.fill")
            }
            .disabled(newTag.isEmpty)
          }
        } header: {
          Text("Tags")
            .lockToggle(isLocked: $tagsLock)
        }

        Section {
          ForEach(links.indices, id: \.self) { index in
            VStack(alignment: .leading) {
              HStack {
                Text(links[index].label)
                  .font(.body)
                Spacer()
                Button(role: .destructive) {
                  let indexToRemove = index
                  withAnimation {
                    links.remove(at: indexToRemove)
                    linksLock = true
                  }
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
                withAnimation {
                  links.append(WebLink(label: newLinkLabel, url: newLinkURL))
                  newLinkLabel = ""
                  newLinkURL = ""
                  linksLock = true
                }
              }
            } label: {
              Label("Add Link", systemImage: "plus.circle.fill")
            }
            .disabled(newLinkLabel.isEmpty || newLinkURL.isEmpty)
          }
        } header: {
          Text("Links")
            .lockToggle(isLocked: $linksLock)
        }
      }
    } controls: {
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
        metadata["titleLock"] = titleLock

        if titleSort != series.metadata.titleSort {
          metadata["titleSort"] = titleSort
        }
        metadata["titleSortLock"] = titleSortLock

        if summary != (series.metadata.summary ?? "") {
          metadata["summary"] = summary.isEmpty ? NSNull() : summary
        }
        metadata["summaryLock"] = summaryLock

        if publisher != (series.metadata.publisher ?? "") {
          metadata["publisher"] = publisher.isEmpty ? NSNull() : publisher
        }
        metadata["publisherLock"] = publisherLock

        if let ageRatingInt = Int(ageRating), ageRatingInt != (series.metadata.ageRating ?? 0) {
          metadata["ageRating"] = ageRating.isEmpty ? NSNull() : ageRatingInt
        } else if ageRating.isEmpty && series.metadata.ageRating != nil {
          metadata["ageRating"] = NSNull()
        }
        metadata["ageRatingLock"] = ageRatingLock

        if let totalBookCountInt = Int(totalBookCount),
          totalBookCountInt != (series.metadata.totalBookCount ?? 0)
        {
          metadata["totalBookCount"] = totalBookCountInt
        } else if totalBookCount.isEmpty && series.metadata.totalBookCount != nil {
          metadata["totalBookCount"] = NSNull()
        }
        metadata["totalBookCountLock"] = totalBookCountLock

        if language != (series.metadata.language ?? "") {
          metadata["language"] = language.isEmpty ? NSNull() : language
        }
        metadata["languageLock"] = languageLock

        let currentReadingDirection = ReadingDirection.fromString(series.metadata.readingDirection)
        if readingDirection != currentReadingDirection {
          metadata["readingDirection"] = readingDirection.rawValue
        }
        metadata["readingDirectionLock"] = readingDirectionLock

        let currentStatus = SeriesStatus.fromString(series.metadata.status)
        if status != currentStatus {
          metadata["status"] = status.apiValue
        }
        metadata["statusLock"] = statusLock

        let currentGenres = series.metadata.genres ?? []
        if genres != currentGenres {
          metadata["genres"] = genres
        }
        metadata["genresLock"] = genresLock

        let currentTags = series.metadata.tags ?? []
        if tags != currentTags {
          metadata["tags"] = tags
        }
        metadata["tagsLock"] = tagsLock

        let currentLinks = series.metadata.links ?? []
        if links != currentLinks {
          metadata["links"] = links.map { ["label": $0.label, "url": $0.url] }
        }
        metadata["linksLock"] = linksLock

        let currentAlternateTitles = series.metadata.alternateTitles ?? []
        if alternateTitles != currentAlternateTitles {
          metadata["alternateTitles"] = alternateTitles.map {
            ["label": $0.label, "title": $0.title]
          }
        }
        metadata["alternateTitlesLock"] = alternateTitlesLock

        if !metadata.isEmpty {
          try await SeriesService.shared.updateSeriesMetadata(
            seriesId: series.id, metadata: metadata)
          await MainActor.run {
            ErrorManager.shared.notify(message: String(localized: "notification.series.updated"))
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
