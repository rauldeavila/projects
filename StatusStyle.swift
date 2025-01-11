// CustomStatus.swift
import SwiftUI

struct CustomStatus: Codable, Identifiable {
    let id: UUID
    var name: String
    var rawValue: String
    var colorHex: String
    
    var color: Color {
        Color(hex: colorHex) ?? .gray
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
        if status == .proj {
            return AnyView(baseText
                .foregroundStyle(.white)
                .background(.black)
                .cornerRadius(4))
        } else if status == .subProj {
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
