import SwiftUI

/// Representa as configurações do aplicativo
class AppSettings: ObservableObject {
    
    static var shared: AppSettings!
    
    private let customStatusKey = "customStatus"
    private let statusStyleKey = "statusStyle"
    
    // Focus settings
    @Published var addItemsInFocusedLevel: Bool = false {
        didSet {
            UserDefaults.standard.set(addItemsInFocusedLevel, forKey: addItemsInFocusedLevelKey)
        }
    }
    private let addItemsInFocusedLevelKey = "addItemsInFocusedLevel"
    
    static let defaultStatuses: [CustomStatus] = [
            CustomStatus(
                id: UUID(),
                name: "Project",
                rawValue: "PROJECT",
                colorHex: "#FFFFFF",
                category: .firstLevel,
                order: 0,
                isDefault: true,
                showCounter: true,
                backgroundColor: "#000000",
                textColor: "#FFFFFF",
                forceCustomColors: true
            ),
            // Intermediate Level
            CustomStatus(
                id: UUID(),
                name: "Subproject",
                rawValue: "SUBPROJECT",
                colorHex: "#808080",
                category: .intermediate,
                order: 0,
                isDefault: true,
                showCounter: true,
                backgroundColor: "#000000",
                textColor: "#808080",
                forceCustomColors: true
            ),
            CustomStatus(
                id: UUID(),
                name: "Project",
                rawValue: "PROJECT",
                colorHex: "#FFFFFF",
                category: .intermediate,
                order: 1,
                isDefault: true,
                showCounter: true,
                backgroundColor: "#000000",
                textColor: "#FFFFFF",
                forceCustomColors: true
            ),
            // Task Level
            CustomStatus(
                id: UUID(),
                name: "Todo",
                rawValue: "TODO",
                colorHex: "#007AFF",
                category: .task,
                order: 0,
                isDefault: true,
                showCounter: false,
                backgroundColor: "#E6F3FF",
                textColor: "#007AFF",
                forceCustomColors: false
            ),
            CustomStatus(
                id: UUID(),
                name: "Next Actions",
                rawValue: "NEXT",
                colorHex: "#9639F5",
                category: .task,
                order: 1,
                isDefault: true,
                showCounter: false,
                backgroundColor: "#F5E6FF",
                textColor: "#9639F5",
                forceCustomColors: false
            ),
            CustomStatus(
                id: UUID(),
                name: "Doing",
                rawValue: "DOING",
                colorHex: "#FFA500",
                category: .task,
                order: 1,
                isDefault: true,
                showCounter: false,
                backgroundColor: "#FFF3E6",
                textColor: "#FFA500",
                forceCustomColors: false
            ),
            CustomStatus(
                id: UUID(),
                name: "Done",
                rawValue: "DONE",
                colorHex: "#00FF00",
                category: .task,
                order: 2,
                isDefault: true,
                showCounter: false,
                backgroundColor: "#E6FFE6",
                textColor: "#008000",
                forceCustomColors: false
            ),
            CustomStatus(
                id: UUID(),
                name: "Bug",
                rawValue: "BUG",
                colorHex: "#F50000",
                category: .task,
                order: 3,
                isDefault: true,
                showCounter: false,
                backgroundColor: "#FFE6E6",
                textColor: "#F50000",
                forceCustomColors: false
            ),
            CustomStatus(
                id: UUID(),
                name: "Read",
                rawValue: "READ",
                colorHex: "#F500E9",
                category: .task,
                order: 3,
                isDefault: true,
                showCounter: false,
                backgroundColor: "#FFE6FC",
                textColor: "#F500E9",
                forceCustomColors: false
            ),
            CustomStatus(
                id: UUID(),
                name: "Waiting",
                rawValue: "WAITING",
                colorHex: "#F58800",
                category: .task,
                order: 3,
                isDefault: true,
                showCounter: false,
                backgroundColor: "#FFF0E6",
                textColor: "#F58800",
                forceCustomColors: false
            )
        ]
    
    init() {
        loadCustomStatus()
        loadStatusStyle()
        loadCustomColors()
        
        // Load saved opacity or use default
        accentOpacity = UserDefaults.standard.double(forKey: accentOpacityKey)
        if accentOpacity == 0 { // If no saved value
            accentOpacity = 0.2 // Default value
        }
        
        // Rest of the init remains the same
        if customStatus.isEmpty {
            customStatus = Self.defaultStatuses
        }
        
        Task { @MainActor in
            do {
                let settings = try await PersistenceManager.shared.loadSettings()
                selectedColorName = settings.selectedColorName
                updateAccentColor(selectedColorName)
            } catch {
                print("Error loading color selection: \(error)")
            }
        }
        
        // Carrega cores salvas ou usa valores padrão
        if let data = UserDefaults.standard.data(forKey: backgroundColorKey),
           let color = try? JSONDecoder().decode(CustomColor.self, from: data) {
            backgroundColor = color.color
        } else {
            backgroundColor = .black
        }

        if let data = UserDefaults.standard.data(forKey: textColorKey),
           let color = try? JSONDecoder().decode(CustomColor.self, from: data) {
            textColor = color.color
        } else {
            textColor = .white
        }

        if let data = UserDefaults.standard.data(forKey: inputBarBackgroundColorKey),
           let color = try? JSONDecoder().decode(CustomColor.self, from: data) {
            inputBarBackgroundColor = color.color
        } else {
            inputBarBackgroundColor = .black
        }

        if let data = UserDefaults.standard.data(forKey: inputBarTextColorKey),
           let color = try? JSONDecoder().decode(CustomColor.self, from: data) {
            inputBarTextColor = color.color
        } else {
            inputBarTextColor = .white
        }

        if let data = UserDefaults.standard.data(forKey: inputBarBorderColorKey),
           let color = try? JSONDecoder().decode(CustomColor.self, from: data) {
            inputBarBorderColor = color.color
        } else {
            inputBarBorderColor = .gray
        }

        inputBarBorderWidth = UserDefaults.standard.double(forKey: inputBarBorderWidthKey)
        if inputBarBorderWidth == 0 {
            inputBarBorderWidth = 1.0
        }

        inputBarCornerRadius = UserDefaults.standard.double(forKey: inputBarCornerRadiusKey)
        if inputBarCornerRadius == 0 {
            inputBarCornerRadius = 4.0
        }

        inputBarShowBorder = UserDefaults.standard.bool(forKey: inputBarShowBorderKey)
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
    
    @Published var backgroundColor: Color = .black
    @Published var textColor: Color = .white
    @Published var inputBarBackgroundColor: Color = .black
    @Published var inputBarTextColor: Color = .white
    @Published var inputBarBorderColor: Color = .gray
    @Published var inputBarBorderWidth: Double = 1.0
    @Published var inputBarCornerRadius: Double = 4.0
    @Published var inputBarShowBorder: Bool = false
    
    private let backgroundColorKey = "backgroundColor"
    private let textColorKey = "textColor"
    private let inputBarBackgroundColorKey = "inputBarBackgroundColor"
    private let inputBarTextColorKey = "inputBarTextColor"
    private let inputBarBorderColorKey = "inputBarBorderColor"
    private let inputBarBorderWidthKey = "inputBarBorderWidth"
    private let inputBarCornerRadiusKey = "inputBarCornerRadius"
    private let inputBarShowBorderKey = "inputBarShowBorder"
    
    /// Todas as cores disponíveis (sistema + personalizadas)
    var availableColors: [(name: String, color: Color)] {
        let system = Self.systemColors
        let custom = customColors.map { (name: $0.name, color: $0.color) }
        return system + custom
    }
    
    private let accentOpacityKey = "accentOpacity"

    // Add published property for opacity
    @Published var accentOpacity: Double = 0.2 {
        didSet {
            UserDefaults.standard.set(accentOpacity, forKey: accentOpacityKey)
        }
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
            category: StatusCategory,
            showCounter: Bool = false,
            backgroundColor: String = "#000000",
            textColor: String = "#FFFFFF",
            forceCustomColors: Bool = false
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
                isDefault: false,
                showCounter: showCounter,
                backgroundColor: backgroundColor,
                textColor: textColor,
                forceCustomColors: forceCustomColors  // Nova propriedade
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
    
    // Adicione estas funções para salvar as cores:
    private func saveColor(_ color: Color, forKey key: String) {
        if let hex = color.toHex() {
            let customColor = CustomColor(id: UUID(), name: "Saved Color", hex: hex)
            if let data = try? JSONEncoder().encode(customColor) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
    
    func updateBackgroundColor(_ color: Color) {
        backgroundColor = color
        saveColor(color, forKey: backgroundColorKey)
    }

    func updateTextColor(_ color: Color) {
        textColor = color
        saveColor(color, forKey: textColorKey)
    }

    func updateInputBarBackgroundColor(_ color: Color) {
        inputBarBackgroundColor = color
        saveColor(color, forKey: inputBarBackgroundColorKey)
    }

    func updateInputBarTextColor(_ color: Color) {
        inputBarTextColor = color
        saveColor(color, forKey: inputBarTextColorKey)
    }

    func updateInputBarBorderColor(_ color: Color) {
        inputBarBorderColor = color
        saveColor(color, forKey: inputBarBorderColorKey)
    }

    func updateInputBarBorderWidth(_ width: Double) {
        inputBarBorderWidth = width
        UserDefaults.standard.set(width, forKey: inputBarBorderWidthKey)
    }

    func updateInputBarCornerRadius(_ radius: Double) {
        inputBarCornerRadius = radius
        UserDefaults.standard.set(radius, forKey: inputBarCornerRadiusKey)
    }

    func updateInputBarShowBorder(_ show: Bool) {
        inputBarShowBorder = show
        UserDefaults.standard.set(show, forKey: inputBarShowBorderKey)
    }
}
