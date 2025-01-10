import SwiftUI
import SwiftData
import OSLog

@MainActor
class PersistenceManager: ObservableObject {
    static let shared = PersistenceManager()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "projects", category: "persistence")
    
    private var modelContainer: ModelContainer
    private var modelContext: ModelContext
    
    @Published var itemsChanged = false
    @Published var settingsChanged = false
    
    private init() {
        do {
            let schema = Schema([
                ItemModel.self,
                AppData.self,
                CustomColorModel.self,
                CustomStatusModel.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            modelContext = modelContainer.mainContext
            
            // Observa mudanças no contexto
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(contextObjectsDidChange),
                name: .NSManagedObjectContextObjectsDidChange,
                object: modelContext
            )
            
            ensureAppDataExists()
            
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }
    
    @objc private func contextObjectsDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        let itemChanges = [
            NSInsertedObjectsKey,
            NSUpdatedObjectsKey,
            NSDeletedObjectsKey
        ].contains { key in
            (userInfo[key] as? Set<NSManagedObject>)?.contains { $0 is ItemModel } ?? false
        }
        
        let settingsChanges = [
            NSInsertedObjectsKey,
            NSUpdatedObjectsKey,
            NSDeletedObjectsKey
        ].contains { key in
            (userInfo[key] as? Set<NSManagedObject>)?.contains { $0 is AppData } ?? false
        }
        
        if itemChanges {
            itemsChanged = true
        }
        if settingsChanges {
            settingsChanged = true
        }
    }
    
    // MARK: - Settings
    
    private func ensureAppDataExists() {
        do {
            let descriptor = FetchDescriptor<AppData>()
            let existingData = try modelContext.fetch(descriptor)
            
            if existingData.isEmpty {
                let appData = AppData()
                modelContext.insert(appData)
                try modelContext.save()
            }
        } catch {
            logger.error("Failed to ensure AppData exists: \(error.localizedDescription)")
        }
    }
    
    func saveSettings(
        selectedColorName: String,
        customColors: [CustomColor],
        customStatus: [CustomStatus],
        statusStyle: StatusStyle
    ) throws {
        let descriptor = FetchDescriptor<AppData>()
        let existingData = try modelContext.fetch(descriptor)
        
        let appData: AppData
        if let existing = existingData.first {
            appData = existing
        } else {
            appData = AppData()
            modelContext.insert(appData)
        }
        
        appData.selectedColorName = selectedColorName
        appData.statusStyle = StatusStyle.allCases.firstIndex(of: statusStyle) ?? 0
        
        // Converte e salva as cores personalizadas
        appData.customColors = customColors.map { CustomColorModel.fromDomain($0) }
        
        // Converte e salva os status personalizados
        appData.customStatus = customStatus.map { CustomStatusModel.fromDomain($0) }
        
        try modelContext.save()
    }
    
    func loadSettings() throws -> (
        selectedColorName: String,
        customColors: [CustomColor],
        customStatus: [CustomStatus],
        statusStyle: StatusStyle
    ) {
        let descriptor = FetchDescriptor<AppData>()
        let appData = try modelContext.fetch(descriptor).first ?? AppData()
        
        return (
            selectedColorName: appData.selectedColorName,
            customColors: appData.customColors.map { $0.toDomain },
            customStatus: appData.customStatus.map { $0.toDomain },
            statusStyle: StatusStyle.allCases[appData.statusStyle]
        )
    }
}

extension PersistenceManager {
    static func destroyPersistentStore() {
        // Obtém o URL do diretório de aplicativos de suporte
        guard let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        
        let storeDirectory = supportDirectory.appendingPathComponent("default.store")
        
        do {
            // Remove todo o diretório do store
            try FileManager.default.removeItem(at: storeDirectory)
        } catch {
            print("Failed to remove store: \(error)")
        }
    }
    
    func resetAllData() throws {
        // Primeiro destruímos o store
        Self.destroyPersistentStore()
        
        // Recriamos o container
        let schema = Schema([
            ItemModel.self,
            AppData.self,
            CustomColorModel.self,
            CustomStatusModel.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        // Recria o container
        modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
        modelContext = modelContainer.mainContext
        
        // Inicializa com dados padrão
        let newAppData = AppData()
        modelContext.insert(newAppData)
        try modelContext.save()
    }
}

@MainActor
extension PersistenceManager {
    func saveItems(_ items: [Item]) throws {
        do {
            // 1. Get all existing items
            let descriptor = FetchDescriptor<ItemModel>()
            let existingModels = try modelContext.fetch(descriptor)
            
            // 2. Create a map of existing models by ID
            let modelMap = Dictionary(uniqueKeysWithValues: existingModels.map { ($0.id, $0) })
            
            // 3. Track valid IDs
            var validIds = Set<UUID>()
            
            // 4. Recursive function to process items and their children
            func processItem(_ item: Item, order: Int, parent: ItemModel?) -> ItemModel {
                if let existingModel = modelMap[item.id] {
                    // Update existing model
                    existingModel.title = item.title
                    existingModel.isCollapsed = item.isCollapsed
                    existingModel.statusRawValue = item.status.rawValue
                    existingModel.statusIsCustom = item.status.isCustom
                    existingModel.statusColorHex = item.status.colorHex
                    existingModel.createdAt = item.createdAt
                    existingModel.modifiedAt = item.modifiedAt
                    existingModel.completedAt = item.completedAt
                    existingModel.order = order
                    existingModel.parent = parent
                    
                    // Process sub-items if they exist
                    if let subItems = item.subItems {
                        let subModels = subItems.enumerated().map { index, subItem in
                            processItem(subItem, order: index, parent: existingModel)
                        }
                        existingModel.subItems = subModels
                    } else {
                        existingModel.subItems = nil
                    }
                    
                    validIds.insert(item.id)
                    return existingModel
                    
                } else {
                    // Create new model
                    let newModel = ItemModel(item: item, order: order)
                    newModel.parent = parent
                    modelContext.insert(newModel)
                    
                    // Process sub-items if they exist
                    if let subItems = item.subItems {
                        let subModels = subItems.enumerated().map { index, subItem in
                            processItem(subItem, order: index, parent: newModel)
                        }
                        newModel.subItems = subModels
                    }
                    
                    validIds.insert(item.id)
                    return newModel
                }
            }
            
            // 5. Process all root items with their order
            let _ = items.enumerated().map { index, item in
                processItem(item, order: index, parent: nil)
            }
            
            // 6. Delete models that are no longer valid
            for model in existingModels where !validIds.contains(model.id) {
                modelContext.delete(model)
            }
            
            // 7. Save changes
            try modelContext.save()
            logger.debug("Successfully saved \(items.count) root items")
            
        } catch {
            logger.error("Failed to save items: \(error.localizedDescription)")
            throw error
        }
    }
    
    func loadItems() throws -> [Item] {
        do {
            // Create a descriptor that sorts by order
            let descriptor = FetchDescriptor<ItemModel>(
                sortBy: [SortDescriptor(\ItemModel.order)]
            )
            
            let models = try modelContext.fetch(descriptor)
            
            // Find root items (those without parents) and convert to domain objects
            let rootModels = models.filter { $0.parent == nil }
                                 .sorted(by: { $0.order < $1.order })
            
            return rootModels.map { $0.toDomain }
            
        } catch {
            logger.error("Failed to load items: \(error.localizedDescription)")
            throw error
        }
    }
}
