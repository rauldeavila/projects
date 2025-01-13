import SwiftUI

/// Representa as configurações do aplicativo
class AppSettings: ObservableObject {
    
    static var shared: AppSettings!
    
    private let customStatusKey = "customStatus"
    private let statusStyleKey = "statusStyle"
    
    
    // Status padrão do sistema
        static let defaultStatuses: [CustomStatus] = [
            // First Level
            CustomStatus(
                id: UUID(),
                name: "Project",
                rawValue: "PROJECT",
                colorHex: "#000000",
                category: .firstLevel,
                order: 0,
                isDefault: true
            ),
            
            // Intermediate Level
            CustomStatus(
                id: UUID(),
                name: "Subproject",
                rawValue: "SUBPROJECT",
                colorHex: "#808080",
                category: .intermediate,
                order: 0,
                isDefault: true
            ),
            CustomStatus(
                id: UUID(),
                name: "Project",
                rawValue: "PROJECT",
                colorHex: "#000000",
                category: .intermediate,
                order: 1,
                isDefault: true
            ),
            
            // Task Level - TODO com a cor azul do SwiftUI
            CustomStatus(
                id: UUID(),
                name: "Todo",
                rawValue: "TODO",
                colorHex: "#007AFF", // Cor azul do SwiftUI
                category: .task,
                order: 0,
                isDefault: true
            ),
            CustomStatus(
                id: UUID(),
                name: "Next Actions",
                rawValue: "NEXT",
                colorHex: "#9639F5",
                category: .task,
                order: 1,
                isDefault: true
            ),
            CustomStatus(
                id: UUID(),
                name: "Doing",
                rawValue: "DOING",
                colorHex: "#FFA500",
                category: .task,
                order: 1,
                isDefault: true
            ),
            CustomStatus(
                id: UUID(),
                name: "Done",
                rawValue: "DONE",
                colorHex: "#00FF00",
                category: .task,
                order: 2,
                isDefault: true
            ),
            CustomStatus(
                id: UUID(),
                name: "Bug",
                rawValue: "BUG",
                colorHex: "#F50000",
                category: .task,
                order: 3,
                isDefault: true
            ),
            CustomStatus(
                id: UUID(),
                name: "Read",
                rawValue: "READ",
                colorHex: "#F500E9",
                category: .task,
                order: 3,
                isDefault: true
            ),
            CustomStatus(
                id: UUID(),
                name: "Waiting",
                rawValue: "WAITING",
                colorHex: "#F58800",
                category: .task,
                order: 3,
                isDefault: true
            )
        ]
    
    init() {
        loadCustomStatus()
        loadStatusStyle()
        loadCustomColors()
        
        // Adiciona os status padrão se ainda não existirem
        if customStatus.isEmpty {
            customStatus = Self.defaultStatuses
        }
        
        // Carrega a cor selecionada
        Task { @MainActor in
            do {
                let settings = try await PersistenceManager.shared.loadSettings()
                selectedColorName = settings.selectedColorName
                updateAccentColor(selectedColorName)
            } catch {
                print("Error loading color selection: \(error)")
            }
        }
    }
    
    // Métodos auxiliares para acessar status por categoria
    func getStatus(for category: StatusCategory) -> [CustomStatus] {
        let categoryStatus = customStatus
            .filter { $0.category == category }
            .sorted { $0.order < $1.order }
        return categoryStatus
    }
    
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
    
    /// Atualiza a cor de accent
    /// Atualiza a cor de accent
    func updateAccentColor(_ colorName: String) {
        if let colorPair = availableColors.first(where: { $0.name == colorName }) {
            selectedColorName = colorPair.name
            accentColor = colorPair.color
            
            // Salva as alterações
            Task { @MainActor in
                do {
                    try await PersistenceManager.shared.saveSettings(
                        selectedColorName: selectedColorName,
                        customColors: customColors,
                        customStatus: customStatus,
                        statusStyle: statusStyle
                    )
                } catch {
                    print("Error saving color selection: \(error)")
                }
            }
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

//    // Métodos auxiliares para acessar status por categoria
//    func getStatus(for category: StatusCategory) -> [CustomStatus] {
//        let defaultStatus = CustomStatus.defaultStatus(for: category)
//        let categoryStatus = customStatus
//            .filter { $0.category == category }
//            .sorted { $0.order < $1.order }
//        
//        return [defaultStatus] + categoryStatus
//    }
    
    func nextAvailableOrder(for category: StatusCategory) -> Int {
        let maxOrder = customStatus
            .filter { $0.category == category }
            .map { $0.order }
            .max() ?? -1
        return maxOrder + 1
    }
    
    // Adiciona um novo status customizado
    func addCustomStatus(
        name: String,
        rawValue: String,
        colorHex: String,
        category: StatusCategory
    ) -> Bool {
        // Verifica se já existe um status com este nome ou rawValue
        guard !customStatus.contains(where: { $0.name == name || $0.rawValue == rawValue }) else {
            return false
        }
        
        let order = nextAvailableOrder(for: category)
        let newStatus = CustomStatus(
            id: UUID(),
            name: name,
            rawValue: rawValue,
            colorHex: colorHex,
            category: category,
            order: order,
            isDefault: false
        )
        
        customStatus.append(newStatus)
        return true
    }
    
    // Remove um status customizado
    func removeCustomStatus(id: UUID) {
        guard let status = customStatus.first(where: { $0.id == id }),
              !status.isDefault else {
            return
        }
        
        let category = status.category
        let oldOrder = status.order
        
        // Remove o status
        customStatus.removeAll { $0.id == id }
        
        // Reordena os status restantes da mesma categoria
        customStatus = customStatus.map { status in
            if status.category == category && status.order > oldOrder {
                var updated = status
                updated.order -= 1
                return updated
            }
            return status
        }
    }
    
    // Atualiza a ordem dos status em uma categoria
    func updateOrder(in category: StatusCategory, oldIndex: Int, newIndex: Int) {
        var categoryStatus = getStatus(for: category)
        guard oldIndex != newIndex,
              oldIndex >= 0, oldIndex < categoryStatus.count,
              newIndex >= 0, newIndex < categoryStatus.count else {
            return
        }
        
        let movedStatus = categoryStatus.remove(at: oldIndex)
        categoryStatus.insert(movedStatus, at: newIndex)
        
        // Atualiza a ordem de todos os status não-padrão
        let updatedStatus = categoryStatus.enumerated().compactMap { index, status -> CustomStatus? in
            guard !status.isDefault else { return nil }
            var updated = status
            updated.order = index - 1 // -1 porque o status padrão é sempre o primeiro
            return updated
        }
        
        // Atualiza apenas os status da categoria modificada
        customStatus = customStatus.filter { $0.category != category } + updatedStatus
    }
}
