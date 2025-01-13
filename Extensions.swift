import SwiftUI

extension Array {
    var nilIfEmpty: Self? {
        isEmpty ? nil : self
    }
}

extension Color {
    /// Inicializa uma cor a partir de um código HEX
    /// - Parameter hex: String contendo o código HEX (ex: "#FF0000" ou "FF0000")
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    /// Retorna o código HEX da cor
    /// - Returns: String contendo o código HEX
    func toHex() -> String? {
        guard let components = NSColor(self).cgColor.components else {
            return nil
        }
        
        let r = Int(round(components[0] * 255.0))
        let g = Int(round(components[1] * 255.0))
        let b = Int(round(components[2] * 255.0))
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    /// Determina se a cor é escura ou clara
    var isDark: Bool {
        guard let components = NSColor(self).cgColor.components else {
            return false
        }
        
        let r = components[0]
        let g = components[1]
        let b = components[2]
        
        // Fórmula YIQ para determinar brilho da cor
        let yiq = ((r * 299) + (g * 587) + (b * 114)) / 1000
        return yiq < 0.5
    }
}

/// Representa uma cor personalizada no sistema
struct CustomColor: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let hex: String
    
    var color: Color {
        Color(hex: hex) ?? .gray
    }
}

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
