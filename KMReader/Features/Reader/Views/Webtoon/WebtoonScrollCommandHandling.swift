//
// WebtoonScrollCommandHandling.swift
//
//

@MainActor
protocol WebtoonScrollCommandHandling: AnyObject {
  func scrollWebtoon(_ direction: WebtoonScrollDirection)
}
