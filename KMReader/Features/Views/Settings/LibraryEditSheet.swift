//
//  LibraryEditSheet.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct LibraryEditSheet: View {
  let library: Library
  @Environment(\.dismiss) private var dismiss
  @State private var libraryUpdate: LibraryUpdate
  @State private var isSaving = false
  @State private var showDirectoryBrowser = false
  @State private var selectedTab = 0

  // For directory exclusions input
  @State private var newExclusion = ""

  init(library: Library) {
    self.library = library
    _libraryUpdate = State(initialValue: LibraryUpdate.from(library))
  }

  private var isValid: Bool {
    !libraryUpdate.name.isEmpty && !libraryUpdate.root.isEmpty
  }

  var body: some View {
    SheetView(
      title: String(localized: "library.edit.title", defaultValue: "Edit Library"),
      size: .large,
      applyFormStyle: true
    ) {
      Form {
        #if os(tvOS)
          generalSection
          scannerSection
          optionsSection
          metadataSection
        #else
          Picker("", selection: $selectedTab) {
            Text(String(localized: "library.add.tab.general", defaultValue: "General")).tag(0)
            Text(String(localized: "library.add.tab.scanner", defaultValue: "Scanner")).tag(1)
            Text(String(localized: "library.add.tab.options", defaultValue: "Options")).tag(2)
            Text(String(localized: "library.add.tab.metadata", defaultValue: "Metadata")).tag(3)
          }
          .pickerStyle(.segmented)
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets())

          switch selectedTab {
          case 0: generalSection
          case 1: scannerSection
          case 2: optionsSection
          case 3: metadataSection
          default: EmptyView()
          }
        #endif
      }
    } controls: {
      Button(action: saveLibrary) {
        if isSaving {
          ProgressView()
        } else {
          Label(String(localized: "common.save"), systemImage: "checkmark")
        }
      }
      .disabled(isSaving || !isValid)
    }
    .sheet(isPresented: $showDirectoryBrowser) {
      DirectoryBrowserSheet(selectedPath: $libraryUpdate.root)
    }
  }

  // MARK: - General Section

  private var generalSection: some View {
    Section(header: Text(String(localized: "library.add.section.general", defaultValue: "General")))
    {
      TextField(
        String(localized: "library.add.field.name", defaultValue: "Name"),
        text: $libraryUpdate.name
      )

      HStack {
        TextField(
          String(localized: "library.add.field.root", defaultValue: "Root Folder"),
          text: $libraryUpdate.root
        )
        #if !os(tvOS)
          Button {
            showDirectoryBrowser = true
          } label: {
            Image(systemName: "folder")
          }
        #endif
      }
    }
  }

  // MARK: - Scanner Section

  private var scannerSection: some View {
    Section(header: Text(String(localized: "library.add.section.scanner", defaultValue: "Scanner")))
    {
      Toggle(
        String(
          localized: "library.add.field.emptyTrashAfterScan", defaultValue: "Empty trash after scan"
        ),
        isOn: $libraryUpdate.emptyTrashAfterScan
      )

      Toggle(
        String(
          localized: "library.add.field.scanForceModifiedTime",
          defaultValue: "Force directory modified time"),
        isOn: $libraryUpdate.scanForceModifiedTime
      )

      Toggle(
        String(localized: "library.add.field.scanOnStartup", defaultValue: "Scan on startup"),
        isOn: $libraryUpdate.scanOnStartup
      )

      Picker(
        String(localized: "library.add.field.scanInterval", defaultValue: "Scan interval"),
        selection: $libraryUpdate.scanInterval
      ) {
        ForEach(ScanInterval.allCases) { interval in
          Text(interval.localizedName).tag(interval)
        }
      }

      // Scan types
      Group {
        Toggle("CBX", isOn: $libraryUpdate.scanCbx)
        Toggle("PDF", isOn: $libraryUpdate.scanPdf)
        Toggle("EPUB", isOn: $libraryUpdate.scanEpub)
      }

      TextField(
        String(
          localized: "library.add.field.oneshotsDirectory", defaultValue: "Oneshots directory"),
        text: $libraryUpdate.oneshotsDirectory
      )

      // Directory exclusions
      VStack(alignment: .leading, spacing: 8) {
        Text(
          String(localized: "library.add.field.exclusions", defaultValue: "Directory exclusions")
        )
        .font(.subheadline)
        .foregroundColor(.secondary)

        ForEach(libraryUpdate.scanDirectoryExclusions, id: \.self) { exclusion in
          HStack {
            Text(exclusion)
            Spacer()
            Button {
              libraryUpdate.scanDirectoryExclusions.removeAll { $0 == exclusion }
            } label: {
              Image(systemName: "minus.circle.fill")
                .foregroundColor(.red)
            }
            .buttonStyle(.plain)
          }
        }

        HStack {
          TextField(
            String(localized: "library.add.field.newExclusion", defaultValue: "Add exclusion"),
            text: $newExclusion
          )
          Button {
            guard !newExclusion.isEmpty else { return }
            libraryUpdate.scanDirectoryExclusions.append(newExclusion)
            newExclusion = ""
          } label: {
            Image(systemName: "plus.circle.fill")
              .foregroundColor(.green)
          }
          .buttonStyle(.plain)
          .disabled(newExclusion.isEmpty)
        }
      }
    }
  }

  // MARK: - Options Section

  private var optionsSection: some View {
    Section(header: Text(String(localized: "library.add.section.options", defaultValue: "Options")))
    {
      Group {
        Text(String(localized: "library.add.subsection.analysis", defaultValue: "Analysis"))
          .font(.subheadline)
          .foregroundColor(.secondary)

        Toggle(
          String(localized: "library.add.field.hashFiles", defaultValue: "Hash files"),
          isOn: $libraryUpdate.hashFiles
        )

        Toggle(
          String(localized: "library.add.field.hashPages", defaultValue: "Hash pages"),
          isOn: $libraryUpdate.hashPages
        )

        Toggle(
          String(localized: "library.add.field.hashKoreader", defaultValue: "Hash KOReader"),
          isOn: $libraryUpdate.hashKoreader
        )

        Toggle(
          String(
            localized: "library.add.field.analyzeDimensions", defaultValue: "Analyze dimensions"),
          isOn: $libraryUpdate.analyzeDimensions
        )
      }

      Group {
        Text(
          String(
            localized: "library.add.subsection.fileManagement", defaultValue: "File Management")
        )
        .font(.subheadline)
        .foregroundColor(.secondary)

        Toggle(
          String(
            localized: "library.add.field.repairExtensions", defaultValue: "Repair extensions"),
          isOn: $libraryUpdate.repairExtensions
        )

        Toggle(
          String(localized: "library.add.field.convertToCbz", defaultValue: "Convert to CBZ"),
          isOn: $libraryUpdate.convertToCbz
        )
      }

      Picker(
        String(localized: "library.add.field.seriesCover", defaultValue: "Series cover"),
        selection: $libraryUpdate.seriesCover
      ) {
        ForEach(SeriesCoverMode.allCases) { mode in
          Text(mode.localizedName).tag(mode)
        }
      }
    }
  }

  // MARK: - Metadata Section

  private var metadataSection: some View {
    Section(
      header: Text(String(localized: "library.add.section.metadata", defaultValue: "Metadata"))
    ) {
      Group {
        Text(String(localized: "library.add.subsection.comicinfo", defaultValue: "ComicInfo"))
          .font(.subheadline)
          .foregroundColor(.secondary)

        Toggle(
          String(
            localized: "library.add.field.importComicInfoBook", defaultValue: "Import book metadata"
          ),
          isOn: $libraryUpdate.importComicInfoBook
        )

        Toggle(
          String(
            localized: "library.add.field.importComicInfoSeries",
            defaultValue: "Import series metadata"),
          isOn: $libraryUpdate.importComicInfoSeries
        )

        Toggle(
          String(
            localized: "library.add.field.importComicInfoSeriesAppendVolume",
            defaultValue: "Append volume to series"),
          isOn: $libraryUpdate.importComicInfoSeriesAppendVolume
        )

        Toggle(
          String(
            localized: "library.add.field.importComicInfoCollection",
            defaultValue: "Import collections"),
          isOn: $libraryUpdate.importComicInfoCollection
        )

        Toggle(
          String(
            localized: "library.add.field.importComicInfoReadList",
            defaultValue: "Import read lists"),
          isOn: $libraryUpdate.importComicInfoReadList
        )
      }

      Group {
        Text(String(localized: "library.add.subsection.epub", defaultValue: "EPUB"))
          .font(.subheadline)
          .foregroundColor(.secondary)

        Toggle(
          String(
            localized: "library.add.field.importEpubBook", defaultValue: "Import book metadata"),
          isOn: $libraryUpdate.importEpubBook
        )

        Toggle(
          String(
            localized: "library.add.field.importEpubSeries", defaultValue: "Import series metadata"),
          isOn: $libraryUpdate.importEpubSeries
        )
      }

      Group {
        Text(String(localized: "library.add.subsection.other", defaultValue: "Other"))
          .font(.subheadline)
          .foregroundColor(.secondary)

        Toggle(
          String(
            localized: "library.add.field.importMylarSeries", defaultValue: "Import Mylar series"),
          isOn: $libraryUpdate.importMylarSeries
        )

        Toggle(
          String(
            localized: "library.add.field.importLocalArtwork", defaultValue: "Import local artwork"),
          isOn: $libraryUpdate.importLocalArtwork
        )

        Toggle(
          String(
            localized: "library.add.field.importBarcodeIsbn", defaultValue: "Import barcode ISBN"),
          isOn: $libraryUpdate.importBarcodeIsbn
        )
      }
    }
  }

  // MARK: - Actions

  private func saveLibrary() {
    isSaving = true
    Task {
      do {
        try await LibraryService.shared.updateLibrary(id: library.id, update: libraryUpdate)
        await LibraryManager.shared.refreshLibraries()
        await MainActor.run {
          ErrorManager.shared.notify(
            message: String(
              localized: "notification.library.updated", defaultValue: "Library updated")
          )
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
}
