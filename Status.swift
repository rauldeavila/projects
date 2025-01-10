import SwiftUI

//enum Status: String, Codable, CaseIterable {
//    case todo = "TODO"
//    case done = "DONE"
//    case inprogress = "IN PROGRESS"
//    case waiting = "WAITING"
//    case maybe = "MAYBE"
//    case read = "READ"
//    case bug = "BUG"
//    
//    var color: Color {
//        switch self {
//        case .todo: return .gray
//        case .done: return .green
//        case .inprogress: return .blue
//        case .waiting: return .orange
//        case .maybe: return .yellow
//        case .read: return .pink
//        case .bug: return .red
//        }
//    }
//    
//    mutating func next() {
//        let allCases = Status.allCases
//        guard let currentIndex = allCases.firstIndex(of: self) else { return }
//        let nextIndex = (currentIndex + 1) % allCases.count
//        self = allCases[nextIndex]
//    }
//}
