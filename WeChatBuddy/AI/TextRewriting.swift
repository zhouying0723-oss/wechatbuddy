import Foundation

struct RewriteRequest: Equatable, Sendable {
    let text: String
    let tone: RewriteTone
}

struct RewriteResult: Equatable, Sendable {
    let text: String
}

enum RewriteTone: String, CaseIterable, Sendable {
    case natural
    case professional
    case friendly
}

protocol TextRewriting: Sendable {
    func rewrite(_ request: RewriteRequest) async throws -> RewriteResult
}
