import SwiftUI

/// Representa as configurações do aplicativo
class AppSettings: ObservableObject {
    /// As cores de accent disponíveis no sistema
    static let availableColors: [(name: String, color: Color)] = [
        ("System", .accentColor),
        ("Blue", .blue),
        ("Purple", .purple),
        ("Pink", .pink),
        ("Red", .red),
        ("Orange", .orange),
        ("Yellow", .yellow),
        ("Green", .green),
        ("Mint", .mint),
        ("Teal", .teal),
        ("Cyan", .cyan),
        ("Indigo", .indigo),
        ("Brown", .brown)
    ]
    
    /// A cor de accent selecionada
    @Published var accentColor: Color = .accentColor
    
    /// O nome da cor selecionada
    @Published var selectedColorName: String = "System"
    
    /// Atualiza a cor de accent
    func updateAccentColor(_ colorName: String) {
        if let colorPair = Self.availableColors.first(where: { $0.name == colorName }) {
            selectedColorName = colorPair.name
            accentColor = colorPair.color
        }
    }
}
