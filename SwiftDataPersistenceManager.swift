import SwiftUI
import SwiftData

@MainActor
class PersistenceManager: ObservableObject {
    static let shared = PersistenceManager()
    
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    
    @Published var itemsChanged = false
    @Published var settingsChanged = false
    
    private init() {
        do {
            let schema = Schema([
                ItemModel.self,
                AppData.self
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
            
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }
    
    @objc private func contextObjectsDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        // Verifica se houve alterações em ItemModel
        let itemChanges = [
            NSInsertedObjectsKey,
            NSUpdatedObjectsKey,
            NSDeletedObjectsKey
        ].contains { key in
            (userInfo[key] as? Set<NSManagedObject>)?.contains { $0 is ItemModel } ?? false
        }
        
        // Verifica se houve alterações em AppData
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
    
    // MARK: - Items
    
    func saveItems(_ items: [Item]) throws {
        let descriptor = FetchDescriptor<ItemModel>()
        let existingItems = try modelContext.fetch(descriptor)
        existingItems.forEach { modelContext.delete($0) }
        
        func createItemModel(_ item: Item) -> ItemModel {
            let model = ItemModel(
                id: item.id,
                title: item.title,
                isCollapsed: item.isCollapsed,
                status: item.status,
                createdAt: item.createdAt,
                modifiedAt: item.modifiedAt,
                completedAt: item.completedAt
            )
            
            if let subItems = item.subItems {
                model.subItems = subItems.map { createItemModel($0) }
            }
            
            return model
        }
        
        items.forEach { item in
            let model = createItemModel(item)
            modelContext.insert(model)
        }
        
        try modelContext.save()
    }
    
    func loadItems() throws -> [Item] {
        let descriptor = FetchDescriptor<ItemModel>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let models = try modelContext.fetch(descriptor)
        
        func createItem(_ model: ItemModel) -> Item {
            Item(
                id: model.id,
                title: model.title,
                status: model.status,
                subItems: model.subItems?.map { createItem($0) },
                createdAt: model.createdAt,
                modifiedAt: model.modifiedAt,
                completedAt: model.completedAt
            )
        }
        
        return models.map { createItem($0) }
    }
    
    // MARK: - Settings
    
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
        appData.customColors = customColors
        appData.customStatus = customStatus
        
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
            customColors: appData.customColors,
            customStatus: appData.customStatus,
            statusStyle: StatusStyle.allCases[appData.statusStyle]
        )
    }
}
