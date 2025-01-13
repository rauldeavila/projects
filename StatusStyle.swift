// CustomStatus.swift
import SwiftUI

enum StatusCategory: String, Codable, CaseIterable {
    case firstLevel = "First Level"
    case intermediate = "Intermediate"
    case task = "Task"
}

struct CustomStatus: Codable, Identifiable {
    let id: UUID
    var name: String
    var rawValue: String
    var colorHex: String
    var category: StatusCategory
    var order: Int
    var isDefault: Bool
    
    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
    
    // Status padrão do sistema
    static let project = CustomStatus(
        id: UUID(),
        name: "Project",
        rawValue: "PROJECT",
        colorHex: "#000000",
        category: .firstLevel,
        order: 0,
        isDefault: true
    )
    
    static let subproject = CustomStatus(
        id: UUID(),
        name: "Subproject",
        rawValue: "SUBPROJECT",
        colorHex: "#808080",
        category: .intermediate,
        order: 0,
        isDefault: true
    )
    
    static let todo = CustomStatus(
        id: UUID(),
        name: "Todo",
        rawValue: "TODO",
        colorHex: "#0000FF",
        category: .task,
        order: 0,
        isDefault: true
    )
    
    // Status padrão por categoria
    static func defaultStatus(for category: StatusCategory) -> CustomStatus {
        switch category {
        case .firstLevel:
            return project
        case .intermediate:
            return subproject
        case .task:
            return todo
        }
    }
}

enum StatusStyle: String, Codable, CaseIterable {
    case system = "System"
    case neutral = "Neutral"
    case black = "Black"
    case white = "White"
    
    func apply(to text: Text, color: Color, status: ItemStatus, fontSize: Double) -> some View {
        let baseText = text
            .font(.system(size: fontSize, design: .monospaced))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        
        // Special handling for project statuses
        if status.rawValue == "PROJECT" {
            return AnyView(baseText
                .foregroundStyle(.white)
                .background(.black)
                .cornerRadius(4))
        } else if status.rawValue == "SUBPROJECT" {
            return AnyView(baseText
                .foregroundStyle(.gray)
                .background(.black)
                .cornerRadius(4))
        }
        
        // Regular status styling
        switch self {
        case .system:
            return AnyView(baseText
                .foregroundStyle(color.opacity(1))
                .background(color.opacity(0.2))
                .cornerRadius(4))
        case .neutral:
            return AnyView(baseText
                .background(color.opacity(0.2))
                .cornerRadius(4))
        case .black:
            return AnyView(baseText
                .foregroundStyle(color.opacity(1))
                .background(.black)
                .cornerRadius(4))
        case .white:
            return AnyView(baseText
                .foregroundStyle(color.opacity(1))
                .background(.white)
                .cornerRadius(4))
        }
    }
}
