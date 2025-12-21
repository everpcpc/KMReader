//
//  LanguagePicker.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct LanguagePicker: View {
  @Binding var selectedLanguage: String
  let allowEmpty: Bool

  init(selectedLanguage: Binding<String>, allowEmpty: Bool = true) {
    self._selectedLanguage = selectedLanguage
    self.allowEmpty = allowEmpty
  }

  private var languageOptions: [String] {
    var options = LanguageCodeHelper.commonLanguageCodes
    if allowEmpty {
      options.insert("", at: 0)
    }
    return options
  }

  var body: some View {
    Picker("Language", selection: $selectedLanguage) {
      ForEach(languageOptions, id: \.self) { code in
        Text(LanguageCodeHelper.displayName(for: code))
          .tag(code)
      }
    }
  }
}
