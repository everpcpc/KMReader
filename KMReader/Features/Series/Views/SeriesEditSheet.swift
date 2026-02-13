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
  @State private var metadataUpdate: SeriesMetadataUpdate
  @State private var isSaving = false

  @State private var selectedTab = 0

  @State private var newGenre: String = ""
  @State private var newTag: String = ""
  @State private var newLinkLabel: String = ""
  @State private var newLinkURL: String = ""
  @State private var newAlternateTitleLabel: String = ""
  @State private var newAlternateTitle: String = ""
  @State private var newSharingLabel: String = ""

  init(series: Series) {
    self.series = series
    _metadataUpdate = State(initialValue: SeriesMetadataUpdate.from(series))
  }

  var body: some View {
    SheetView(title: String(localized: "Edit Series"), size: .large, applyFormStyle: true) {
      Form {
        Picker("", selection: $selectedTab) {
          Text(String(localized: "series.edit.tab.general", defaultValue: "General")).tag(0)
          Text(String(localized: "series.edit.tab.title", defaultValue: "Title")).tag(1)
          Text(String(localized: "series.edit.tab.tags", defaultValue: "Tags")).tag(2)
          Text(String(localized: "series.edit.tab.links", defaultValue: "Links")).tag(3)
          Text(String(localized: "series.edit.tab.sharing", defaultValue: "Sharing")).tag(4)
        }
        .pickerStyle(.segmented)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())

        switch selectedTab {
        case 0: generalTab
        case 1: titleTab
        case 2: tagsTab
        case 3: linksTab
        case 4: sharingTab
        default: EmptyView()
        }
      }
    } controls: {
      Button(action: saveChanges) {
        if isSaving {
          LoadingIcon()
        } else {
          Label("Save", systemImage: "checkmark")
        }
      }
      .disabled(isSaving)
    }
  }

  private var generalTab: some View {
    Group {
      Section("Summary") {
        TextField("Summary", text: $metadataUpdate.summary, axis: .vertical)
          .lineLimit(3...10)
          .lockToggle(isLocked: $metadataUpdate.summaryLock, alignment: .top)
          .onChange(of: metadataUpdate.summary) { metadataUpdate.summaryLock = true }
      }

      Section("Status") {
        Picker("Status", selection: $metadataUpdate.status) {
          ForEach(SeriesStatus.allCases, id: \.self) { status in
            Text(status.displayName).tag(status)
          }
        }
        .lockToggle(isLocked: $metadataUpdate.statusLock)
        .onChange(of: metadataUpdate.status) { metadataUpdate.statusLock = true }
      }

      Section("Reading & Language") {
        Picker("Reading Direction", selection: $metadataUpdate.readingDirection) {
          ForEach(ReadingDirection.allCases, id: \.self) { direction in
            Text(direction.displayName).tag(direction)
          }
        }
        .lockToggle(isLocked: $metadataUpdate.readingDirectionLock)
        .onChange(of: metadataUpdate.readingDirection) { metadataUpdate.readingDirectionLock = true }

        LanguagePicker(selectedLanguage: $metadataUpdate.language)
          .lockToggle(isLocked: $metadataUpdate.languageLock)
          .onChange(of: metadataUpdate.language) { metadataUpdate.languageLock = true }
      }

      Section("Publication") {
        TextField("Publisher", text: $metadataUpdate.publisher)
          .lockToggle(isLocked: $metadataUpdate.publisherLock)
          .onChange(of: metadataUpdate.publisher) { metadataUpdate.publisherLock = true }

        TextField("Age Rating", text: $metadataUpdate.ageRating)
          #if os(iOS) || os(tvOS)
            .keyboardType(.numberPad)
          #endif
          .lockToggle(isLocked: $metadataUpdate.ageRatingLock)
          .onChange(of: metadataUpdate.ageRating) { metadataUpdate.ageRatingLock = true }

        TextField("Total Book Count", text: $metadataUpdate.totalBookCount)
          #if os(iOS) || os(tvOS)
            .keyboardType(.numberPad)
          #endif
          .lockToggle(isLocked: $metadataUpdate.totalBookCountLock)
          .onChange(of: metadataUpdate.totalBookCount) { metadataUpdate.totalBookCountLock = true }
      }
    }
  }

  private var titleTab: some View {
    Group {
      Section("Titles") {
        TextField("Title", text: $metadataUpdate.title)
          .lockToggle(isLocked: $metadataUpdate.titleLock)
          .onChange(of: metadataUpdate.title) { metadataUpdate.titleLock = true }
        TextField("Title Sort", text: $metadataUpdate.titleSort)
          .lockToggle(isLocked: $metadataUpdate.titleSortLock)
          .onChange(of: metadataUpdate.titleSort) { metadataUpdate.titleSortLock = true }
      }

      Section {
        ForEach(metadataUpdate.alternateTitles.indices, id: \.self) { index in
          VStack(alignment: .leading) {
            HStack {
              Text(metadataUpdate.alternateTitles[index].label)
              Spacer()
              Button(role: .destructive) {
                let indexToRemove = index
                withAnimation {
                  metadataUpdate.alternateTitles.remove(at: indexToRemove)
                  metadataUpdate.alternateTitlesLock = true
                }
              } label: {
                Image(systemName: "trash")
              }
            }
            Text(metadataUpdate.alternateTitles[index].title)
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
                metadataUpdate.alternateTitles.append(
                  AlternateTitle(label: newAlternateTitleLabel, title: newAlternateTitle))
                newAlternateTitleLabel = ""
                newAlternateTitle = ""
                metadataUpdate.alternateTitlesLock = true
              }
            }
          } label: {
            Label("Add Alternate Title", systemImage: "plus.circle.fill")
          }
          .disabled(newAlternateTitleLabel.isEmpty || newAlternateTitle.isEmpty)
        }
      } header: {
        Text("Alternate Titles")
          .lockToggle(isLocked: $metadataUpdate.alternateTitlesLock)
      }
    }
  }

  private var tagsTab: some View {
    Group {
      Section {
        ForEach(metadataUpdate.genres.indices, id: \.self) { index in
          HStack {
            Text(metadataUpdate.genres[index])
            Spacer()
            Button(role: .destructive) {
              let indexToRemove = index
              withAnimation {
                metadataUpdate.genres.remove(at: indexToRemove)
                metadataUpdate.genresLock = true
              }
            } label: {
              Image(systemName: "trash")
            }
          }
        }
        HStack {
          TextField("Genre", text: $newGenre)
          Button {
            if !newGenre.isEmpty && !metadataUpdate.genres.contains(newGenre) {
              withAnimation {
                metadataUpdate.genres.append(newGenre)
                newGenre = ""
                metadataUpdate.genresLock = true
              }
            }
          } label: {
            Image(systemName: "plus.circle.fill")
          }
          .disabled(newGenre.isEmpty)
        }
      } header: {
        Text("Genres")
          .lockToggle(isLocked: $metadataUpdate.genresLock)
      }

      Section {
        ForEach(metadataUpdate.tags.indices, id: \.self) { index in
          HStack {
            Text(metadataUpdate.tags[index])
            Spacer()
            Button(role: .destructive) {
              let indexToRemove = index
              withAnimation {
                metadataUpdate.tags.remove(at: indexToRemove)
                metadataUpdate.tagsLock = true
              }
            } label: {
              Image(systemName: "trash")
            }
          }
        }
        HStack {
          TextField("Tag", text: $newTag)
          Button {
            if !newTag.isEmpty && !metadataUpdate.tags.contains(newTag) {
              withAnimation {
                metadataUpdate.tags.append(newTag)
                newTag = ""
                metadataUpdate.tagsLock = true
              }
            }
          } label: {
            Image(systemName: "plus.circle.fill")
          }
          .disabled(newTag.isEmpty)
        }
      } header: {
        Text("Tags")
          .lockToggle(isLocked: $metadataUpdate.tagsLock)
      }
    }
  }

  private var linksTab: some View {
    Section {
      ForEach(metadataUpdate.links.indices, id: \.self) { index in
        VStack(alignment: .leading) {
          HStack {
            Text(metadataUpdate.links[index].label)
            Spacer()
            Button(role: .destructive) {
              let indexToRemove = index
              withAnimation {
                metadataUpdate.links.remove(at: indexToRemove)
                metadataUpdate.linksLock = true
              }
            } label: {
              Image(systemName: "trash")
            }
          }
          Text(metadataUpdate.links[index].url)
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
              metadataUpdate.links.append(WebLink(label: newLinkLabel, url: newLinkURL))
              newLinkLabel = ""
              newLinkURL = ""
              metadataUpdate.linksLock = true
            }
          }
        } label: {
          Label("Add Link", systemImage: "plus.circle.fill")
        }
        .disabled(newLinkLabel.isEmpty || newLinkURL.isEmpty)
      }
    } header: {
      Text("Links")
        .lockToggle(isLocked: $metadataUpdate.linksLock)
    }
  }

  private var sharingTab: some View {
    Section {
      ForEach(metadataUpdate.sharingLabels.indices, id: \.self) { index in
        HStack {
          Text(metadataUpdate.sharingLabels[index])
          Spacer()
          Button(role: .destructive) {
            let indexToRemove = index
            withAnimation {
              metadataUpdate.sharingLabels.remove(at: indexToRemove)
              metadataUpdate.sharingLabelsLock = true
            }
          } label: {
            Image(systemName: "trash")
          }
        }
      }
      HStack {
        TextField("Label", text: $newSharingLabel)
        Button {
          if !newSharingLabel.isEmpty && !metadataUpdate.sharingLabels.contains(newSharingLabel) {
            withAnimation {
              metadataUpdate.sharingLabels.append(newSharingLabel)
              newSharingLabel = ""
              metadataUpdate.sharingLabelsLock = true
            }
          }
        } label: {
          Image(systemName: "plus.circle.fill")
        }
        .disabled(newSharingLabel.isEmpty)
      }
    } header: {
      Text("Sharing Labels")
        .lockToggle(isLocked: $metadataUpdate.sharingLabelsLock)
    }
  }

  private func saveChanges() {
    isSaving = true
    Task {
      do {
        let metadata = metadataUpdate.toAPIDict(against: series)

        if !metadata.isEmpty {
          try await SeriesService.shared.updateSeriesMetadata(
            seriesId: series.id, metadata: metadata)
          ErrorManager.shared.notify(message: String(localized: "notification.series.updated"))
          dismiss()
        } else {
          dismiss()
        }
      } catch {
        ErrorManager.shared.alert(error: error)
      }
      isSaving = false
    }
  }
}
