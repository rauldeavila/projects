import SwiftUI

/// Representa as configurações do aplicativo
class AppSettings: ObservableObject {
    
    static var shared: AppSettings!
    
    private let customStatusKey = "customStatus"
    private let statusStyleKey = "statusStyle"
    
    /// As cores de accent disponíveis no sistema
    static let systemColors: [(name: String, color: Color)] = [
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
        ("Indigo", .indigo),
        ("Brown", .brown)
    ]
    
    /// Chave para salvar cores personalizadas no UserDefaults
    private let customColorsKey = "customColors"
    
    /// A cor de accent selecionada
    @Published var accentColor: Color = .accentColor
    
    /// O nome da cor selecionada
    @Published var selectedColorName: String = "System"
    
    /// Array de cores personalizadas
    @Published var customColors: [CustomColor] = [] {
        didSet {
            saveCustomColors()
        }
    }
    
    @Published var customStatus: [CustomStatus] = [] {
        didSet {
            saveCustomStatus()
        }
    }

    @Published var statusStyle: StatusStyle = .system {
        didSet {
            UserDefaults.standard.set(try? JSONEncoder().encode(statusStyle), forKey: statusStyleKey)
        }
    }
    
    /// Todas as cores disponíveis (sistema + personalizadas)
    var availableColors: [(name: String, color: Color)] {
        let system = Self.systemColors
        let custom = customColors.map { (name: $0.name, color: $0.color) }
        return system + custom
    }
    
    init() {
        loadCustomColors()
        loadCustomStatus()
        loadStatusStyle()
    }
    
    /// Atualiza a cor de accent
    func updateAccentColor(_ colorName: String) {
        if let colorPair = availableColors.first(where: { $0.name == colorName }) {
            selectedColorName = colorPair.name
            accentColor = colorPair.color
        }
    }
    
    /// Adiciona uma nova cor personalizada
    /// - Parameters:
    ///   - name: Nome da cor
    ///   - hex: Código HEX da cor
    /// - Returns: True se a cor foi adicionada com sucesso
    @discardableResult
    func addCustomColor(name: String, hex: String) -> Bool {
        // Verifica se o nome já existe
        guard !availableColors.contains(where: { $0.name == name }) else {
            return false
        }
        
        // Verifica se o código HEX é válido
        guard Color(hex: hex) != nil else {
            return false
        }
        
        let newColor = CustomColor(id: UUID(), name: name, hex: hex)
        customColors.append(newColor)
        return true
    }
    
    /// Remove uma cor personalizada
    /// - Parameter id: ID da cor a ser removida
    func removeCustomColor(id: UUID) {
        customColors.removeAll { $0.id == id }
    }
    
    /// Carrega cores personalizadas do UserDefaults
    private func loadCustomColors() {
        if let data = UserDefaults.standard.data(forKey: customColorsKey),
           let colors = try? JSONDecoder().decode([CustomColor].self, from: data) {
            customColors = colors
        }
    }
    
    /// Salva cores personalizadas no UserDefaults
    private func saveCustomColors() {
        if let data = try? JSONEncoder().encode(customColors) {
            UserDefaults.standard.set(data, forKey: customColorsKey)
        }
    }
    
    
    private func loadCustomStatus() {
        if let data = UserDefaults.standard.data(forKey: customStatusKey),
           let status = try? JSONDecoder().decode([CustomStatus].self, from: data) {
            customStatus = status
        }
    }
    
    private func saveCustomStatus() {
        if let data = try? JSONEncoder().encode(customStatus) {
            UserDefaults.standard.set(data, forKey: customStatusKey)
        }
    }

    private func loadStatusStyle() {
        if let data = UserDefaults.standard.data(forKey: statusStyleKey),
           let style = try? JSONDecoder().decode(StatusStyle.self, from: data) {
            statusStyle = style
        }
    }

    func addCustomStatus(name: String, rawValue: String, colorHex: String) -> Bool {
        // Verifica se já existe um status com este nome ou rawValue
        guard !customStatus.contains(where: { $0.name == name || $0.rawValue == rawValue }) else {
            return false
        }
        
        let newStatus = CustomStatus(id: UUID(), name: name, rawValue: rawValue, colorHex: colorHex)
        customStatus.append(newStatus)
        return true
    }

    func removeCustomStatus(id: UUID) {
        customStatus.removeAll { $0.id == id }
    }
}
