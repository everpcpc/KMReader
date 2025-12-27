//
//  OneshotEditSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct OneshotEditSheet: View {
  let series: Series
  let book: Book
  @Environment(\.dismiss) private var dismiss
  @State private var isSaving = false

  // Book metadata fields
  @State private var title: String
  @State private var titleLock: Bool
  @State private var summary: String
  @State private var summaryLock: Bool
  @State private var releaseDate: Date?
  @State private var releaseDateString: String
  @State private var releaseDateLock: Bool
  @State private var isbn: String
  @State private var isbnLock: Bool
  @State private var authors: [Author]
  @State private var authorsLock: Bool
  @State private var bookTags: [String]
  @State private var bookTagsLock: Bool
  @State private var links: [WebLink]
  @State private var linksLock: Bool

  // Series metadata fields
  @State private var titleSort: String
  @State private var titleSortLock: Bool
  @State private var readingDirection: ReadingDirection
  @State private var readingDirectionLock: Bool
  @State private var language: String
  @State private var languageLock: Bool
  @State private var publisher: String
  @State private var publisherLock: Bool
  @State private var ageRating: String
  @State private var ageRatingLock: Bool
  @State private var genres: [String]
  @State private var genresLock: Bool
  @State private var sharingLabels: [String]
  @State private var sharingLabelsLock: Bool

  // Input fields for adding new items
  @State private var newAuthorName: String = ""
  @State private var newAuthorRole: AuthorRole = .writer
  @State private var customRoleName: String = ""
  @State private var newGenre: String = ""
  @State private var newBookTag: String = ""
  @State private var newSharingLabel: String = ""
  @State private var newLinkLabel: String = ""
  @State private var newLinkURL: String = ""

  init(series: Series, book: Book) {
    self.series = series
    self.book = book

    // Book metadata
    _title = State(initialValue: book.metadata.title)
    _titleLock = State(initialValue: book.metadata.titleLock ?? false)
    _summary = State(initialValue: book.metadata.summary ?? "")
    _summaryLock = State(initialValue: book.metadata.summaryLock ?? false)

    if let dateString = book.metadata.releaseDate, !dateString.isEmpty {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withFullDate]
      _releaseDate = State(initialValue: formatter.date(from: dateString))
      _releaseDateString = State(initialValue: dateString)
    } else {
      _releaseDate = State(initialValue: nil)
      _releaseDateString = State(initialValue: "")
    }
    _releaseDateLock = State(initialValue: book.metadata.releaseDateLock ?? false)

    _isbn = State(initialValue: book.metadata.isbn ?? "")
    _isbnLock = State(initialValue: book.metadata.isbnLock ?? false)
    _authors = State(initialValue: book.metadata.authors ?? [])
    _authorsLock = State(initialValue: book.metadata.authorsLock ?? false)
    _bookTags = State(initialValue: book.metadata.tags ?? [])
    _bookTagsLock = State(initialValue: book.metadata.tagsLock ?? false)
    _links = State(initialValue: book.metadata.links ?? [])
    _linksLock = State(initialValue: book.metadata.linksLock ?? false)

    // Series metadata
    _titleSort = State(initialValue: series.metadata.titleSort)
    _titleSortLock = State(initialValue: series.metadata.titleSortLock ?? false)
    _readingDirection = State(
      initialValue: ReadingDirection.fromString(series.metadata.readingDirection)
    )
    _readingDirectionLock = State(initialValue: series.metadata.readingDirectionLock ?? false)
    _language = State(initialValue: series.metadata.language ?? "")
    _languageLock = State(initialValue: series.metadata.languageLock ?? false)
    _publisher = State(initialValue: series.metadata.publisher ?? "")
    _publisherLock = State(initialValue: series.metadata.publisherLock ?? false)
    _ageRating = State(initialValue: series.metadata.ageRating.map { String($0) } ?? "")
    _ageRatingLock = State(initialValue: series.metadata.ageRatingLock ?? false)
    _genres = State(initialValue: series.metadata.genres ?? [])
    _genresLock = State(initialValue: series.metadata.genresLock ?? false)
    _sharingLabels = State(initialValue: series.metadata.sharingLabels ?? [])
    _sharingLabelsLock = State(initialValue: series.metadata.sharingLabelsLock ?? false)
  }

  var body: some View {
    SheetView(title: String(localized: "Edit Oneshot"), size: .large, applyFormStyle: true) {
      Form {
        basicInformationSection
        readingSettingsSection
        authorsSection
        genresSection
        bookTagsSection
        sharingLabelsSection
        linksSection
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

  // MARK: - Sections

  private var basicInformationSection: some View {
    Section("Basic Information") {
      TextField("Title", text: $title)
        .lockToggle(isLocked: $titleLock)
        .onChange(of: title) { titleLock = true }
      TextField("Sort Title", text: $titleSort)
        .lockToggle(isLocked: $titleSortLock)
        .onChange(of: titleSort) { titleSortLock = true }
      TextField("Summary", text: $summary, axis: .vertical)
        .lineLimit(3...10)
        .lockToggle(isLocked: $summaryLock)
        .onChange(of: summary) { summaryLock = true }

      #if os(tvOS)
        HStack {
          TextField("Release Date (YYYY-MM-DD)", text: $releaseDateString)
            .onChange(of: releaseDateString) { _, newValue in
              let formatter = ISO8601DateFormatter()
              formatter.formatOptions = [.withFullDate]
              releaseDate = formatter.date(from: newValue)
              releaseDateLock = true
            }

          if !releaseDateString.isEmpty {
            Button(action: {
              withAnimation {
                releaseDateString = ""
                releaseDate = nil
                releaseDateLock = true
              }
            }) {
              Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
            }
            .adaptiveButtonStyle(.plain)
          }
        }
        .lockToggle(isLocked: $releaseDateLock)
      #else
        HStack {
          DatePicker(
            "Release Date",
            selection: Binding(
              get: { releaseDate ?? Date(timeIntervalSince1970: 0) },
              set: {
                releaseDate = $0
                releaseDateLock = true
              }
            ),
            displayedComponents: .date
          )
          .datePickerStyle(.compact)

          if releaseDate != nil {
            Button(action: {
              withAnimation {
                releaseDate = nil
                releaseDateLock = true
              }
            }) {
              Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
            }
            .adaptiveButtonStyle(.plain)
          }
        }
        .lockToggle(isLocked: $releaseDateLock)
      #endif

      TextField("ISBN", text: $isbn)
        #if os(iOS) || os(tvOS)
          .keyboardType(.default)
        #endif
        .lockToggle(isLocked: $isbnLock)
        .onChange(of: isbn) { isbnLock = true }
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
  }

  private var readingSettingsSection: some View {
    Section("Reading Settings") {
      Picker("Reading Direction", selection: $readingDirection) {
        ForEach(ReadingDirection.allCases, id: \.self) { direction in
          Text(direction.displayName).tag(direction)
        }
      }
      .lockToggle(isLocked: $readingDirectionLock)
      .onChange(of: readingDirection) { readingDirectionLock = true }

      LanguagePicker(selectedLanguage: $language)
        .lockToggle(isLocked: $languageLock)
        .onChange(of: language) { languageLock = true }
    }
  }

  private var authorsSection: some View {
    Section {
      ForEach(authors.indices, id: \.self) { index in
        HStack {
          VStack(alignment: .leading) {
            Text(authors[index].name)
              .font(.body)
            Text(authors[index].role.displayName)
              .font(.caption)
              .foregroundColor(.secondary)
          }
          Spacer()
          Button(role: .destructive) {
            let indexToRemove = index
            withAnimation {
              authors.remove(at: indexToRemove)
              authorsLock = true
            }
          } label: {
            Image(systemName: "trash")
          }
        }
      }
      VStack {
        HStack {
          TextField("Name", text: $newAuthorName)
          Picker("Role", selection: $newAuthorRole) {
            ForEach(AuthorRole.predefinedCases, id: \.self) { role in
              Text(role.displayName).tag(role)
            }
            Text("Custom").tag(AuthorRole.custom(""))
          }
          .frame(maxWidth: 150)
        }

        if case .custom = newAuthorRole {
          HStack {
            TextField("Custom Role", text: $customRoleName)
          }
        }

        Button {
          if !newAuthorName.isEmpty {
            let finalRole: AuthorRole
            if case .custom = newAuthorRole {
              finalRole = .custom(customRoleName.isEmpty ? "Custom" : customRoleName)
            } else {
              finalRole = newAuthorRole
            }
            withAnimation {
              authors.append(Author(name: newAuthorName, role: finalRole))
              newAuthorName = ""
              newAuthorRole = .writer
              customRoleName = ""
              authorsLock = true
            }
          }
        } label: {
          Label("Add Author", systemImage: "plus.circle.fill")
        }
        .disabled(newAuthorName.isEmpty)
      }
    } header: {
      Text("Authors")
        .lockToggle(isLocked: $authorsLock)
    }
  }

  private var genresSection: some View {
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
  }

  private var bookTagsSection: some View {
    Section {
      ForEach(bookTags.indices, id: \.self) { index in
        HStack {
          Text(bookTags[index])
          Spacer()
          Button(role: .destructive) {
            let indexToRemove = index
            withAnimation {
              bookTags.remove(at: indexToRemove)
              bookTagsLock = true
            }
          } label: {
            Image(systemName: "trash")
          }
        }
      }
      HStack {
        TextField("Tag", text: $newBookTag)
        Button {
          if !newBookTag.isEmpty && !bookTags.contains(newBookTag) {
            withAnimation {
              bookTags.append(newBookTag)
              newBookTag = ""
              bookTagsLock = true
            }
          }
        } label: {
          Image(systemName: "plus.circle.fill")
        }
        .disabled(newBookTag.isEmpty)
      }
    } header: {
      Text("Tags")
        .lockToggle(isLocked: $bookTagsLock)
    }
  }

  private var sharingLabelsSection: some View {
    Section {
      ForEach(sharingLabels.indices, id: \.self) { index in
        HStack {
          Text(sharingLabels[index])
          Spacer()
          Button(role: .destructive) {
            let indexToRemove = index
            withAnimation {
              sharingLabels.remove(at: indexToRemove)
              sharingLabelsLock = true
            }
          } label: {
            Image(systemName: "trash")
          }
        }
      }
      HStack {
        TextField("Label", text: $newSharingLabel)
        Button {
          if !newSharingLabel.isEmpty && !sharingLabels.contains(newSharingLabel) {
            withAnimation {
              sharingLabels.append(newSharingLabel)
              newSharingLabel = ""
              sharingLabelsLock = true
            }
          }
        } label: {
          Image(systemName: "plus.circle.fill")
        }
        .disabled(newSharingLabel.isEmpty)
      }
    } header: {
      Text("Sharing Labels")
        .lockToggle(isLocked: $sharingLabelsLock)
    }
  }

  private var linksSection: some View {
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

  // MARK: - Save

  private func saveChanges() {
    isSaving = true
    Task {
      do {
        // Update book metadata
        try await saveBookMetadata()
        // Update series metadata
        try await saveSeriesMetadata()

        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "notification.book.updated"))
          dismiss()
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

  private func saveBookMetadata() async throws {
    var metadata: [String: Any] = [:]

    if title != book.metadata.title {
      metadata["title"] = title
    }
    metadata["titleLock"] = titleLock

    if summary != (book.metadata.summary ?? "") {
      metadata["summary"] = summary.isEmpty ? NSNull() : summary
    }
    metadata["summaryLock"] = summaryLock

    if let date = releaseDate {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withFullDate]
      let dateString = formatter.string(from: date)
      if dateString != (book.metadata.releaseDate ?? "") {
        metadata["releaseDate"] = dateString
      }
    } else if book.metadata.releaseDate != nil {
      metadata["releaseDate"] = NSNull()
    }
    metadata["releaseDateLock"] = releaseDateLock

    if isbn != (book.metadata.isbn ?? "") {
      metadata["isbn"] = isbn.isEmpty ? NSNull() : isbn
    }
    metadata["isbnLock"] = isbnLock

    let currentAuthors = book.metadata.authors ?? []
    if authors != currentAuthors {
      metadata["authors"] = authors.map { ["name": $0.name, "role": $0.role] }
    }
    metadata["authorsLock"] = authorsLock

    let currentBookTags = book.metadata.tags ?? []
    if bookTags != currentBookTags {
      metadata["tags"] = bookTags
    }
    metadata["tagsLock"] = bookTagsLock

    let currentLinks = book.metadata.links ?? []
    if links != currentLinks {
      metadata["links"] = links.map { ["label": $0.label, "url": $0.url] }
    }
    metadata["linksLock"] = linksLock

    if !metadata.isEmpty {
      try await BookService.shared.updateBookMetadata(bookId: book.id, metadata: metadata)
    }
  }

  private func saveSeriesMetadata() async throws {
    var metadata: [String: Any] = [:]

    if titleSort != series.metadata.titleSort {
      metadata["titleSort"] = titleSort
    }
    metadata["titleSortLock"] = titleSortLock

    let currentReadingDirection = ReadingDirection.fromString(series.metadata.readingDirection)
    if readingDirection != currentReadingDirection {
      metadata["readingDirection"] = readingDirection.rawValue
    }
    metadata["readingDirectionLock"] = readingDirectionLock

    if language != (series.metadata.language ?? "") {
      metadata["language"] = language.isEmpty ? NSNull() : language
    }
    metadata["languageLock"] = languageLock

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

    let currentGenres = series.metadata.genres ?? []
    if genres != currentGenres {
      metadata["genres"] = genres
    }
    metadata["genresLock"] = genresLock

    let currentSharingLabels = series.metadata.sharingLabels ?? []
    if sharingLabels != currentSharingLabels {
      metadata["sharingLabels"] = sharingLabels
    }
    metadata["sharingLabelsLock"] = sharingLabelsLock

    if !metadata.isEmpty {
      try await SeriesService.shared.updateSeriesMetadata(
        seriesId: series.id, metadata: metadata)
    }
  }
}
