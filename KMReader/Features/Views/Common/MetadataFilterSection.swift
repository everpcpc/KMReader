//
//  MetadataFilterSection.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct MetadataFilterSection: View {
  @Binding var metadataFilter: MetadataFilterConfig
  let libraryIds: [String]?
  let collectionId: String?
  let seriesId: String?
  let readListId: String?
  let showPublisher: Bool
  let showAuthors: Bool
  let showGenres: Bool
  let showTags: Bool
  let showLanguages: Bool

  @State private var publishers: [String] = []
  @State private var authors: [String] = []
  @State private var genres: [String] = []
  @State private var tags: [String] = []
  @State private var languages: [String] = []
  @State private var isLoading = false

  init(
    metadataFilter: Binding<MetadataFilterConfig>,
    libraryIds: [String]? = nil,
    collectionId: String? = nil,
    seriesId: String? = nil,
    readListId: String? = nil,
    showPublisher: Bool = false,
    showAuthors: Bool = false,
    showGenres: Bool = false,
    showTags: Bool = false,
    showLanguages: Bool = false
  ) {
    self._metadataFilter = metadataFilter
    self.libraryIds = libraryIds
    self.collectionId = collectionId
    self.seriesId = seriesId
    self.readListId = readListId
    self.showPublisher = showPublisher
    self.showAuthors = showAuthors
    self.showGenres = showGenres
    self.showTags = showTags
    self.showLanguages = showLanguages
  }

  var body: some View {
    if showPublisher || showAuthors || showGenres || showTags || showLanguages {
      Section(String(localized: "Metadata")) {
        if showPublisher {
          publisherPicker
        }

        if showAuthors {
          authorsSection
        }

        if showGenres {
          genresSection
        }

        if showTags {
          tagsSection
        }

        if showLanguages {
          languagesSection
        }
      }
      .task {
        await loadMetadata()
      }
    }
  }

  @ViewBuilder
  private var publisherPicker: some View {
    if isLoading {
      HStack {
        Text(String(localized: "Publisher"))
        Spacer()
        ProgressView()
      }
    } else if !publishers.isEmpty {
      NavigationLink {
        PublisherSelectList(
          publishers: publishers,
          selectedPublisher: Binding(
            get: { metadataFilter.publisher },
            set: { metadataFilter.publisher = $0 }
          )
        )
      } label: {
        HStack {
          Text(String(localized: "Publisher"))
          Spacer()
          if let publisher = metadataFilter.publisher {
            Text(publisher)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var authorsSection: some View {
    if !authors.isEmpty {
      NavigationLink {
        MultiSelectList(
          title: String(localized: "Authors"),
          items: authors,
          selectedItems: Binding(
            get: { Set(metadataFilter.authors ?? []) },
            set: { metadataFilter.authors = $0.isEmpty ? nil : Array($0).sorted() }
          ),
          logic: $metadataFilter.authorsLogic
        )
      } label: {
        HStack {
          Text(String(localized: "Authors"))
          Spacer()
          if let authors = metadataFilter.authors, !authors.isEmpty {
            let logicSymbol = metadataFilter.authorsLogic == .all ? "∧" : "∨"
            Text(authors.joined(separator: " \(logicSymbol) "))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
      }
    } else if isLoading {
      HStack {
        Text(String(localized: "Authors"))
        Spacer()
        ProgressView()
      }
    }
  }

  @ViewBuilder
  private var genresSection: some View {
    if !genres.isEmpty {
      NavigationLink {
        MultiSelectList(
          title: String(localized: "Genres"),
          items: genres,
          selectedItems: Binding(
            get: { Set(metadataFilter.genres ?? []) },
            set: { metadataFilter.genres = $0.isEmpty ? nil : Array($0).sorted() }
          ),
          logic: $metadataFilter.genresLogic
        )
      } label: {
        HStack {
          Text(String(localized: "Genres"))
          Spacer()
          if let genres = metadataFilter.genres, !genres.isEmpty {
            let logicSymbol = metadataFilter.genresLogic == .all ? "∧" : "∨"
            Text(genres.joined(separator: " \(logicSymbol) "))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
      }
    } else if isLoading {
      HStack {
        Text(String(localized: "Genres"))
        Spacer()
        ProgressView()
      }
    }
  }

  @ViewBuilder
  private var tagsSection: some View {
    if !tags.isEmpty {
      NavigationLink {
        MultiSelectList(
          title: String(localized: "Tags"),
          items: tags,
          selectedItems: Binding(
            get: { Set(metadataFilter.tags ?? []) },
            set: { metadataFilter.tags = $0.isEmpty ? nil : Array($0).sorted() }
          ),
          logic: $metadataFilter.tagsLogic
        )
      } label: {
        HStack {
          Text(String(localized: "Tags"))
          Spacer()
          if let tags = metadataFilter.tags, !tags.isEmpty {
            let logicSymbol = metadataFilter.tagsLogic == .all ? "∧" : "∨"
            Text(tags.joined(separator: " \(logicSymbol) "))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
      }
    } else if isLoading {
      HStack {
        Text(String(localized: "Tags"))
        Spacer()
        ProgressView()
      }
    }
  }

  @ViewBuilder
  private var languagesSection: some View {
    if !languages.isEmpty {
      NavigationLink {
        MultiSelectList(
          title: String(localized: "Languages"),
          items: languages,
          selectedItems: Binding(
            get: { Set(metadataFilter.languages ?? []) },
            set: { metadataFilter.languages = $0.isEmpty ? nil : Array($0).sorted() }
          ),
          logic: $metadataFilter.languagesLogic,
          displayNameTransform: { LanguageCodeHelper.displayName(for: $0) }
        )
      } label: {
        HStack {
          Text(String(localized: "Languages"))
          Spacer()
          if let languages = metadataFilter.languages, !languages.isEmpty {
            let logicSymbol = metadataFilter.languagesLogic == .all ? "∧" : "∨"
            let displayNames = languages.map { LanguageCodeHelper.displayName(for: $0) }
            Text(displayNames.joined(separator: " \(logicSymbol) "))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
      }
    } else if isLoading {
      HStack {
        Text(String(localized: "Languages"))
        Spacer()
        ProgressView()
      }
    }
  }

  private func loadMetadata() async {
    isLoading = true
    defer { isLoading = false }

    async let publishersTask: [String]? =
      showPublisher
      ? try? await ReferentialService.shared.getPublishers(
        libraryIds: libraryIds, collectionId: collectionId) : nil
    async let authorsTask: [String]? =
      showAuthors
      ? try? await ReferentialService.shared.getAuthorsNames() : nil
    async let genresTask: [String]? =
      showGenres
      ? try? await ReferentialService.shared.getGenres(
        libraryIds: libraryIds, collectionId: collectionId) : nil
    async let tagsTask: [String]? =
      showTags
      ? (seriesId != nil || readListId != nil
        ? try? await ReferentialService.shared.getBookTags(
          seriesId: seriesId, readListId: readListId, libraryIds: libraryIds)
        : try? await ReferentialService.shared.getTags(
          libraryIds: libraryIds, collectionId: collectionId)) : nil
    async let languagesTask: [String]? =
      showLanguages
      ? try? await ReferentialService.shared.getLanguages(
        libraryIds: libraryIds, collectionId: collectionId) : nil

    let results = await (publishersTask, authorsTask, genresTask, tagsTask, languagesTask)

    if let fetchedPublishers = results.0 {
      publishers = fetchedPublishers
    }
    if let fetchedAuthors = results.1 {
      authors = fetchedAuthors
    }
    if let fetchedGenres = results.2 {
      genres = fetchedGenres
    }
    if let fetchedTags = results.3 {
      tags = fetchedTags
    }
    if let fetchedLanguages = results.4 {
      languages = fetchedLanguages
    }
  }
}

struct MultiSelectList: View {
  let title: String
  let items: [String]
  @Binding var selectedItems: Set<String>
  @Binding var logic: FilterLogic
  let displayNameTransform: ((String) -> String)?
  @Environment(\.dismiss) private var dismiss
  @State private var searchText: String = ""

  init(
    title: String,
    items: [String],
    selectedItems: Binding<Set<String>>,
    logic: Binding<FilterLogic>,
    displayNameTransform: ((String) -> String)? = nil
  ) {
    self.title = title
    self.items = items
    self._selectedItems = selectedItems
    self._logic = logic
    self.displayNameTransform = displayNameTransform
  }

  private var filteredItems: [String] {
    if searchText.isEmpty {
      return items
    }
    return items.filter { item in
      let displayName = displayNameTransform?(item) ?? item
      return displayName.localizedCaseInsensitiveContains(searchText)
    }
  }

  var body: some View {
    List {
      Section {
        Picker(String(localized: "Logic"), selection: $logic) {
          Text(String(localized: "All")).tag(FilterLogic.all)
          Text(String(localized: "Any")).tag(FilterLogic.any)
        }
        .pickerStyle(.segmented)
      }

      Section {
        ForEach(filteredItems, id: \.self) { item in
          SelectableRow(
            item: item,
            displayName: displayNameTransform?(item) ?? item,
            isSelected: selectedItems.contains(item)
          ) {
            toggleSelection(for: item)
          }
        }
      }
    }
    .searchable(text: $searchText, prompt: String(localized: "Search"))
    .inlineNavigationBarTitle(title)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button(String(localized: "Reset")) {
          selectedItems.removeAll()
        }
        .disabled(selectedItems.isEmpty)
      }
      ToolbarItem(placement: .confirmationAction) {
        Button(String(localized: "Done")) {
          dismiss()
        }
      }
    }
  }

  private func toggleSelection(for item: String) {
    if selectedItems.contains(item) {
      selectedItems.remove(item)
    } else {
      selectedItems.insert(item)
    }
  }
}

struct SelectableRow: View {
  let item: String
  let displayName: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack {
        Text(displayName)
        Spacer()
        if isSelected {
          Image(systemName: "checkmark")
            .foregroundStyle(.green)
        }
      }
    }
  }
}

struct PublisherSelectList: View {
  let publishers: [String]
  @Binding var selectedPublisher: String?
  @Environment(\.dismiss) private var dismiss
  @State private var searchText: String = ""

  private var filteredPublishers: [String] {
    if searchText.isEmpty {
      return publishers
    }
    return publishers.filter { publisher in
      publisher.localizedCaseInsensitiveContains(searchText)
    }
  }

  var body: some View {
    List {
      Section {
        ForEach(filteredPublishers, id: \.self) { publisher in
          Button {
            // Toggle selection: if already selected, deselect; otherwise select
            if selectedPublisher == publisher {
              selectedPublisher = nil
            } else {
              selectedPublisher = publisher
            }
          } label: {
            HStack {
              Text(publisher)
              Spacer()
              if selectedPublisher == publisher {
                Image(systemName: "checkmark")
                  .foregroundStyle(.green)
              }
            }
          }
        }
      }
    }
    .searchable(text: $searchText, prompt: String(localized: "Search"))
    .inlineNavigationBarTitle(String(localized: "Publisher"))
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button(String(localized: "Reset")) {
          selectedPublisher = nil
        }
        .disabled(selectedPublisher == nil)
      }
      ToolbarItem(placement: .confirmationAction) {
        Button(String(localized: "Done")) {
          dismiss()
        }
      }
    }
  }
}
