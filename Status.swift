import SwiftUI

enum Status: String, Codable, CaseIterable {
    case todo = "TODO"
    case done = "DONE"
    case work = "WORK"
    case wait = "WAIT"
    case maybe = "MAYB"
    
    var color: Color {
        switch self {
        case .todo: return .gray
        case .done: return .green
        case .work: return .blue
        case .wait: return .orange
        case .maybe: return .yellow
        }
    }
    
    mutating func next() {
        let allCases = Status.allCases
        guard let currentIndex = allCases.firstIndex(of: self) else { return }
        let nextIndex = (currentIndex + 1) % allCases.count
        self = allCases[nextIndex]
    }
}
