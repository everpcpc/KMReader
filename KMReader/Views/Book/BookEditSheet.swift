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
  @State private var summary: String
  @State private var number: String
  @State private var releaseDate: String
  @State private var isbn: String
  @State private var authors: [Author]
  @State private var tags: [String]
  @State private var links: [WebLink]

  @State private var newAuthorName: String = ""
  @State private var newAuthorRole: String = "Writer"
  @State private var newTag: String = ""
  @State private var newLinkLabel: String = ""
  @State private var newLinkURL: String = ""

  init(book: Book) {
    self.book = book
    _title = State(initialValue: book.metadata.title)
    _summary = State(initialValue: book.metadata.summary ?? "")
    _number = State(initialValue: book.metadata.number)
    _releaseDate = State(initialValue: book.metadata.releaseDate ?? "")
    _isbn = State(initialValue: book.metadata.isbn ?? "")
    _authors = State(initialValue: book.metadata.authors ?? [])
    _tags = State(initialValue: book.metadata.tags ?? [])
    _links = State(initialValue: book.metadata.links ?? [])
  }

  var body: some View {
    SheetView(title: "Edit Book", size: .large) {
        Form {
        Section("Basic Information") {
          TextField("Title", text: $title)
          TextField("Number", text: $number)
          TextField("Release Date", text: $releaseDate)
            #if os(iOS) || os(tvOS)
              .keyboardType(.default)
            #endif
          TextField("ISBN", text: $isbn)
            #if os(iOS) || os(tvOS)
              .keyboardType(.default)
            #endif
          TextField("Summary", text: $summary, axis: .vertical)
            .lineLimit(3...10)
        }

        Section("Authors") {
          ForEach(authors.indices, id: \.self) { index in
            HStack {
              VStack(alignment: .leading) {
                Text(authors[index].name)
                  .font(.body)
                Text(authors[index].role)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
              Spacer()
              Button(role: .destructive) {
                authors.remove(at: index)
              } label: {
                Image(systemName: "trash")
              }
            }
          }
          HStack {
            TextField("Name", text: $newAuthorName)
            TextField("Role", text: $newAuthorRole)
            Button {
              if !newAuthorName.isEmpty {
                authors.append(Author(name: newAuthorName, role: newAuthorRole))
                newAuthorName = ""
                newAuthorRole = "Writer"
              }
            } label: {
              Image(systemName: "plus.circle.fill")
            }
            .disabled(newAuthorName.isEmpty)
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

        if title != book.metadata.title {
          metadata["title"] = title
        }
        if summary != (book.metadata.summary ?? "") {
          metadata["summary"] = summary.isEmpty ? NSNull() : summary
        }
        if number != book.metadata.number {
          metadata["number"] = number
        }
        if releaseDate != (book.metadata.releaseDate ?? "") {
          metadata["releaseDate"] = releaseDate.isEmpty ? NSNull() : releaseDate
        }
        if isbn != (book.metadata.isbn ?? "") {
          metadata["isbn"] = isbn.isEmpty ? NSNull() : isbn
        }

        let currentAuthors = book.metadata.authors ?? []
        if authors != currentAuthors {
          metadata["authors"] = authors.map { ["name": $0.name, "role": $0.role] }
        }

        let currentTags = book.metadata.tags ?? []
        if tags != currentTags {
          metadata["tags"] = tags
        }

        let currentLinks = book.metadata.links ?? []
        if links != currentLinks {
          metadata["links"] = links.map { ["label": $0.label, "url": $0.url] }
        }

        if !metadata.isEmpty {
          try await BookService.shared.updateBookMetadata(bookId: book.id, metadata: metadata)
          await MainActor.run {
            ErrorManager.shared.notify(message: "Book updated")
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
