//
//  CustomFontsSheet.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import CoreText
import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

struct CustomFontsSheet: View {
  @State private var customFontInput: String = ""
  @State private var showFontInputError: Bool = false
  @State private var fontInputErrorMessage: String = ""
  @State private var customFonts: [String] = AppConfig.customFontNames
  @State private var showFontPicker: Bool = false

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        #if canImport(UIKit)
          Section {
            Button {
              showFontPicker = true
            } label: {
              HStack {
                Label("Pick Font from System", systemImage: "textformat")
                Spacer()
                Image(systemName: "chevron.right")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          } header: {
            Text("System Font Picker")
          } footer: {
            Text("Select from the system preinstalled fonts")
          }
        #endif

        Section {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
              TextField("Font name", text: $customFontInput)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .onSubmit {
                  addCustomFont()
                }
              Button {
                addCustomFont()
              } label: {
                HStack(spacing: 4) {
                  Image(systemName: "plus.circle.fill")
                  Text("Add")
                }.foregroundStyle(.white)
              }
              .buttonStyle(.borderedProminent)
            }
            if showFontInputError {
              Text(fontInputErrorMessage)
                .font(.caption)
                .foregroundStyle(.red)
            }
          }
          .padding(.vertical, 4)
        } header: {
          Text("Manual Entry")
        } footer: {
          Text(
            "To find font names, go to Settings > General > Fonts on your device. All fonts, including profile-installed fonts, are available."
          )
        }

        if !customFonts.isEmpty {
          Section {
            ForEach(customFonts, id: \.self) { fontName in
              HStack {
                Text(fontName)
                  .font(.system(size: 14, design: .monospaced))
                  .textSelection(.enabled)
                Spacer()
                Button {
                  removeCustomFont(fontName)
                } label: {
                  Label("Delete", systemImage: "trash")
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
              }
            }
          } header: {
            Text("Custom Fonts")
          } footer: {
            Text("\(customFonts.count) custom font\(customFonts.count == 1 ? "" : "s") added")
          }
        }
      }
      .navigationTitle("Custom Fonts")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            dismiss()
          } label: {
            Label("Done", systemImage: "checkmark")
          }
        }
      }
      #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFontPicker) {
          FontPickerView(isPresented: $showFontPicker) { selectedFont in
            handleFontPickerSelection(selectedFont)
          }
        }
      #endif
    }
  }

  private func handleFontPickerSelection(_ font: UIFont) {
    // Get font family name
    let familyName = font.familyName

    // Check if font already exists in custom fonts
    if customFonts.contains(familyName) {
      // Font already added, just clear any error
      showFontInputError = false
      fontInputErrorMessage = ""
      return
    }

    // Add font to custom fonts list (even if it's in system fonts,
    // because it might be a profile-installed font that we want to ensure is available)
    var updatedFonts = customFonts
    updatedFonts.append(familyName)
    let sortedFonts = updatedFonts.sorted()
    AppConfig.customFontNames = sortedFonts
    customFonts = sortedFonts

    // Refresh font provider
    FontProvider.refresh()

    // Clear any error
    showFontInputError = false
    fontInputErrorMessage = ""
  }

  private func addCustomFont() {
    let fontName = customFontInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !fontName.isEmpty else {
      showFontInputError = true
      fontInputErrorMessage = "Font name cannot be empty"
      return
    }

    // Check if font already exists in custom fonts
    if customFonts.contains(fontName) {
      showFontInputError = true
      fontInputErrorMessage = "Font already added"
      return
    }

    // Check if font already exists in system fonts
    if FontProvider.allChoices.contains(where: { $0.rawValue == fontName }) {
      showFontInputError = true
      fontInputErrorMessage = "Font already available in system fonts"
      return
    }

    // Verify font exists by trying to create it
    if !isFontAvailable(fontName) {
      showFontInputError = true
      fontInputErrorMessage = "Font not found. Make sure the font name is correct."
      return
    }

    // Add font to custom fonts list
    var updatedFonts = customFonts
    updatedFonts.append(fontName)
    let sortedFonts = updatedFonts.sorted()
    AppConfig.customFontNames = sortedFonts
    customFonts = sortedFonts

    // Clear input and error
    customFontInput = ""
    showFontInputError = false
    fontInputErrorMessage = ""

    // Refresh font provider
    FontProvider.refresh()
  }

  private func removeCustomFont(_ fontName: String) {
    var updatedFonts = customFonts
    updatedFonts.removeAll { $0 == fontName }
    AppConfig.customFontNames = updatedFonts
    customFonts = updatedFonts

    // Refresh font provider
    FontProvider.refresh()
  }

  private func isFontAvailable(_ fontName: String) -> Bool {
    #if canImport(UIKit)
      // Try to create a UIFont with the name
      if let font = UIFont(name: fontName, size: 12) {
        return font.familyName == fontName || font.fontName == fontName
      }
      // Also try with CTFont (always succeeds, but we check the family name)
      let ctFont = CTFontCreateWithName(fontName as CFString, 12, nil)
      let familyName = CTFontCopyFamilyName(ctFont) as String?
      if let familyName = familyName, familyName == fontName {
        return true
      }
      // Try PostScript name as well
      let postScriptName = CTFontCopyPostScriptName(ctFont) as String?
      if let postScriptName = postScriptName, postScriptName == fontName {
        return true
      }
    #elseif canImport(AppKit)
      if let font = NSFont(name: fontName, size: 12) {
        return font.familyName == fontName || font.fontName == fontName
      }
    #endif
    return false
  }
}

#if canImport(UIKit)
  struct FontPickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onFontSelected: (UIFont) -> Void

    func makeUIViewController(context: Context) -> UIFontPickerViewController {
      let picker = UIFontPickerViewController()
      picker.delegate = context.coordinator
      return picker
    }

    func updateUIViewController(_ uiViewController: UIFontPickerViewController, context: Context) {
      context.coordinator.isPresented = $isPresented
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(isPresented: $isPresented, onFontSelected: onFontSelected)
    }

    class Coordinator: NSObject, UIFontPickerViewControllerDelegate {
      var isPresented: Binding<Bool>
      let onFontSelected: (UIFont) -> Void

      init(isPresented: Binding<Bool>, onFontSelected: @escaping (UIFont) -> Void) {
        self.isPresented = isPresented
        self.onFontSelected = onFontSelected
      }

      func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
        guard let selectedFontDescriptor = viewController.selectedFontDescriptor else {
          return
        }

        // Create a font from the descriptor
        let font = UIFont(descriptor: selectedFontDescriptor, size: 12)
        onFontSelected(font)

        // Dismiss the picker
        DispatchQueue.main.async {
          self.isPresented.wrappedValue = false
        }
      }
    }
  }
#endif
