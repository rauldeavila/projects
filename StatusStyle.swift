// CustomStatus.swift
import SwiftUI

enum StatusCategory: String, Codable, CaseIterable {
    case firstLevel = "First Level"
    case intermediate = "Intermediate"
    case task = "Task"
}

struct CustomStatus: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var rawValue: String
    var colorHex: String
    var category: StatusCategory
    var order: Int
    var isDefault: Bool
    var showCounter: Bool
    var backgroundColor: String
    var textColor: String
    var forceCustomColors: Bool // Nova propriedade
    
    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
    
    var bgColor: Color {
        Color(hex: backgroundColor) ?? .black
    }
    
    var txtColor: Color {
        Color(hex: textColor) ?? .white
    }
    
    static func == (lhs: CustomStatus, rhs: CustomStatus) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum StatusStyle: String, Codable, CaseIterable {
    case system = "System"
    case neutral = "Neutral"
    case black = "Black"
    case white = "White"
    case custom = "Custom Colors"
    
    func apply(to text: Text, color: Color, status: ItemStatus, fontSize: Double) -> some View {
        let baseText = text
            .font(.system(size: fontSize, design: .monospaced))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        
        // Se tem customStatus e forceCustomColors está ativo, ignora o estilo global
        if let customStatus = status.customStatus, customStatus.forceCustomColors {
            return AnyView(baseText
                .foregroundStyle(customStatus.txtColor)
                .background(customStatus.bgColor)
                .cornerRadius(4))
        }
        
        // Caso contrário, segue o estilo normal
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
                
        case .custom:
            if let customStatus = status.customStatus {
                return AnyView(baseText
                    .foregroundStyle(customStatus.txtColor)
                    .background(customStatus.bgColor)
                    .cornerRadius(4))
            } else {
                return AnyView(baseText
                    .foregroundStyle(color)
                    .background(Color.black)
                    .cornerRadius(4))
            }
        }
    }
}
