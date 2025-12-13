//
//  BookEditSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BookEditSheet: View {
  let book: Book
  @Environment(\.dismiss) private var dismiss
  @State private var isSaving = false

  // Book metadata fields
  @State private var title: String
  @State private var titleLock: Bool
  @State private var summary: String
  @State private var summaryLock: Bool
  @State private var number: String
  @State private var numberLock: Bool
  @State private var numberSort: String
  @State private var numberSortLock: Bool
  @State private var releaseDate: Date?
  @State private var releaseDateLock: Bool
  @State private var isbn: String
  @State private var isbnLock: Bool
  @State private var authors: [Author]
  @State private var authorsLock: Bool
  @State private var tags: [String]
  @State private var tagsLock: Bool
  @State private var links: [WebLink]
  @State private var linksLock: Bool

  @State private var newAuthorName: String = ""
  @State private var newAuthorRole: AuthorRole = .writer
  @State private var showCustomRoleInput: Bool = false
  @State private var customRoleName: String = ""
  @State private var newTag: String = ""
  @State private var newLinkLabel: String = ""
  @State private var newLinkURL: String = ""

  init(book: Book) {
    self.book = book
    _title = State(initialValue: book.metadata.title)
    _titleLock = State(initialValue: book.metadata.titleLock ?? false)
    _summary = State(initialValue: book.metadata.summary ?? "")
    _summaryLock = State(initialValue: book.metadata.summaryLock ?? false)
    _number = State(initialValue: book.metadata.number)
    _numberLock = State(initialValue: book.metadata.numberLock ?? false)
    _numberSort = State(initialValue: String(book.metadata.numberSort))
    _numberSortLock = State(initialValue: book.metadata.numberSortLock ?? false)

    // Parse release date from string
    if let dateString = book.metadata.releaseDate, !dateString.isEmpty {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withFullDate]
      _releaseDate = State(initialValue: formatter.date(from: dateString))
    } else {
      _releaseDate = State(initialValue: nil)
    }
    _releaseDateLock = State(initialValue: book.metadata.releaseDateLock ?? false)

    _isbn = State(initialValue: book.metadata.isbn ?? "")
    _isbnLock = State(initialValue: book.metadata.isbnLock ?? false)
    _authors = State(initialValue: book.metadata.authors ?? [])
    _authorsLock = State(initialValue: book.metadata.authorsLock ?? false)
    _tags = State(initialValue: book.metadata.tags ?? [])
    _tagsLock = State(initialValue: book.metadata.tagsLock ?? false)
    _links = State(initialValue: book.metadata.links ?? [])
    _linksLock = State(initialValue: book.metadata.linksLock ?? false)
  }

  var body: some View {
    SheetView(title: String(localized: "Edit Book"), size: .large, applyFormStyle: true) {
      Form {
        Section("Basic Information") {
          TextField("Title", text: $title)
            .lockToggle(isLocked: $titleLock)
          TextField("Number", text: $number)
            .lockToggle(isLocked: $numberLock)
          TextField("Number Sort", text: $numberSort)
            #if os(iOS) || os(tvOS)
              .keyboardType(.decimalPad)
            #endif
            .lockToggle(isLocked: $numberSortLock)

          HStack {
            DatePicker(
              "Release Date",
              selection: Binding(
                get: { releaseDate ?? Date(timeIntervalSince1970: 0) },
                set: {
                  releaseDate = $0
                }
              ),
              displayedComponents: .date
            )
            .datePickerStyle(.compact)

            if releaseDate != nil {
              Button(action: {
                withAnimation {
                  releaseDate = nil
                }
              }) {
                Image(systemName: "xmark.circle.fill")
                  .foregroundColor(.secondary)
              }
              .buttonStyle(.plain)
            }
          }
          .lockToggle(isLocked: $releaseDateLock)

          TextField("ISBN", text: $isbn)
            #if os(iOS) || os(tvOS)
              .keyboardType(.default)
            #endif
            .lockToggle(isLocked: $isbnLock)
          TextField("Summary", text: $summary, axis: .vertical)
            .lineLimit(3...10)
            .lockToggle(isLocked: $summaryLock)
        }

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
                _ = withAnimation {
                  authors.remove(at: indexToRemove)
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
                  .textFieldStyle(.roundedBorder)
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

        Section {
          ForEach(tags.indices, id: \.self) { index in
            HStack {
              Text(tags[index])
              Spacer()
              Button(role: .destructive) {
                let indexToRemove = index
                _ = withAnimation {
                  tags.remove(at: indexToRemove)
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
                  _ = withAnimation {
                    links.remove(at: indexToRemove)
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

        if title != book.metadata.title {
          metadata["title"] = title
        }
        metadata["titleLock"] = titleLock

        if summary != (book.metadata.summary ?? "") {
          metadata["summary"] = summary.isEmpty ? NSNull() : summary
        }
        metadata["summaryLock"] = summaryLock

        if number != book.metadata.number {
          metadata["number"] = number
        }
        metadata["numberLock"] = numberLock

        if let numberSortDouble = Double(numberSort), numberSortDouble != book.metadata.numberSort {
          metadata["numberSort"] = numberSortDouble
        }
        metadata["numberSortLock"] = numberSortLock

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

        let currentTags = book.metadata.tags ?? []
        if tags != currentTags {
          metadata["tags"] = tags
        }
        metadata["tagsLock"] = tagsLock

        let currentLinks = book.metadata.links ?? []
        if links != currentLinks {
          metadata["links"] = links.map { ["label": $0.label, "url": $0.url] }
        }
        metadata["linksLock"] = linksLock

        if !metadata.isEmpty {
          try await BookService.shared.updateBookMetadata(bookId: book.id, metadata: metadata)
          await MainActor.run {
            ErrorManager.shared.notify(message: String(localized: "notification.book.updated"))
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
