import SwiftUI
import OSLog

struct FlattenedItem: Identifiable {
    let id = UUID()
    let item: Item
    let level: Int
}

/// View model to manage the task list state
class TaskListViewModel: ObservableObject {

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "projects", category: "view-model")

    @Published private(set) var items: [Item] = []
    private var needsSave = false
    private var saveTask: Task<Void, Never>?
    
    @Published var editingItemId: UUID?
    @Published var newItemText: String = ""
    @Published var selectedItemId: UUID?
    @Published var editingDirection: EditDirection = .right
    @Published var shakeSelected: Bool = false
    @Published var focusedItemId: UUID?
    @Published private var allCollapsed: Bool = false
    @Published var isShowingDeleteConfirmation: Bool = false
    @Published var deleteConfirmationOption: DeleteOption = .yes
    
    @ObservedObject var settings: AppSettings
    
    
    init(settings: AppSettings) {
        self.settings = settings
        loadItems()
    }
    
    private func saveChanges() {
        logger.debug("Saving changes. Current items count: \(self.items.count)")
        do {
            try PersistenceManager.shared.saveItems(items)
            logger.debug("Successfully saved items")
        } catch {
            logger.error("Failed to save items: \(error.localizedDescription)")
        }
    }
    
    private func enqueueSave() {
        needsSave = true
        
        // Cancela qualquer tarefa de salvamento pendente
        saveTask?.cancel()
        
        // Cria uma nova tarefa de salvamento
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
            
            guard !Task.isCancelled && needsSave else { return }
            
            do {
                try PersistenceManager.shared.saveItems(items)
                needsSave = false
            } catch {
                logger.error("Failed to save items: \(error.localizedDescription)")
            }
        }
    }
    
    func updateItems(_ newItems: [Item]) {
        items = newItems
        enqueueSave()
    }
    
    func addItem(_ title: String) {
        var currentItems = items
        let newItem = Item(title: title)
        currentItems.append(newItem)
        updateItems(currentItems)
    }
    
    private func loadItems() {
        do {
            items = try PersistenceManager.shared.loadItems()
        } catch {
            logger.error("Failed to load items: \(error.localizedDescription)")
        }
    }
    
    
    func updateItemTitle(_ id: UUID, newTitle: String) {
        func updateTitle(in items: inout [Item]) -> Bool {
            for index in items.indices {
                if items[index].id == id {
                    items[index].title = newTitle
                    items[index].touch()
                    return true
                }
                
                if var subItems = items[index].subItems {
                    if updateTitle(in: &subItems) {
                        items[index].subItems = subItems
                        return true
                    }
                }
            }
            return false
        }
        
        var updatedItems = items
        if updateTitle(in: &updatedItems) {
            items = updatedItems
            saveChanges()
        }
        editingItemId = nil
    }
    
    // Status groups for cycling based on hierarchy
        private func getAvailableStatuses(for item: Item) -> [ItemStatus] {
            
            // Se tem filhos, oferecemos status baseado no nível hierárquico
            if !item.isTask {
                if item.hierarchyLevel == 0 {
                    // Nível raiz: PROJECT e outros status de primeiro nível
                    return settings.getStatus(for: .firstLevel)
                        .map { ItemStatus.custom($0.rawValue, colorHex: $0.colorHex) }
                } else {
                    // Níveis mais profundos: SUBPROJECT e outros status intermediários
                    return settings.getStatus(for: .intermediate)
                        .map { ItemStatus.custom($0.rawValue, colorHex: $0.colorHex) }
                }
            }
            
            // Para tasks simples (sem filhos), oferecemos todos os status de task
            return settings.getStatus(for: .task)
                .map { ItemStatus.custom($0.rawValue, colorHex: $0.colorHex) }
        }

        func cycleSelectedItemStatus(direction: Int = 1) {
            guard let selectedId = selectedItemId else { return }
            
            updateItemInHierarchy(itemId: selectedId) { item in
                let availableStatuses = getAvailableStatuses(for: item)
                
                if let currentIndex = availableStatuses.firstIndex(of: item.status) {
                    let nextIndex = (currentIndex + direction + availableStatuses.count) % availableStatuses.count
                    item.status = availableStatuses[nextIndex]
                } else if let firstStatus = availableStatuses.first {
                    // Usa o primeiro status disponível como fallback
                    item.status = firstStatus
                }
                
                item.touch()
            }
            
            // Após mudar o status, atualiza os status DONE em toda a árvore
            var updatedItems = items
            updateDoneStatuses(items: &updatedItems)
            items = updatedItems
            
            saveChanges()
        }

    func deleteSelectedItem() {
        guard let selectedId = selectedItemId else { return }
        
            func deleteItem(in items: inout [Item]) -> Bool {
                // Primeiro, procura no nível atual
                if let index = items.firstIndex(where: { $0.id == selectedId }) {
                    // Remove o item e todos os seus filhos de uma vez
                    items.remove(at: index)
                    return true
                }
                
                // Se não encontrou no nível atual, procura recursivamente nos subníveis
                for index in items.indices {
                    if var subItems = items[index].subItems {
                        if deleteItem(in: &subItems) {
                            // Atualiza os subitems do pai
                            items[index].subItems = subItems
                            // Se ficou sem filhos, atualiza o status
                            if subItems.isEmpty {
                                items[index].subItems = nil
                                if let todoStatus = settings.getStatus(for: .task).first {
                                    items[index].status = .custom(todoStatus.rawValue, colorHex: todoStatus.colorHex)
                                }
                                items[index].touch()
                            }
                            return true
                        }
                    }
                }
                return false
            }
                
            var updatedItems = items
            if deleteItem(in: &updatedItems) {
                items = updatedItems
                saveChanges()
                editingItemId = nil
                isShowingDeleteConfirmation = false
            }
        }
    

    // Current focused item index
    private var currentIndex: Int? {
        if let selectedId = selectedItemId {
            return items.firstIndex { $0.id == selectedId }
        }
        return nil
    }
    
    enum EditDirection {
        case left
        case right
    }
    
    
    enum DeleteOption {
        case yes
        case no
        
        mutating func toggle() {
            self = self == .yes ? .no : .yes
        }
    }
    
    func handleDeleteConfirmation(confirmed: Bool) {
        if confirmed {
            // Store the current index before deletion
            let flatList = buildFlattenedList(items: items)
            let currentIndex = flatList.firstIndex { $0.item.id == selectedItemId }
            
            // Delete the item
            deleteSelectedItem()
            
            // Select the previous item if it exists
            if let currentIndex = currentIndex, currentIndex > 0 {
                selectedItemId = flatList[currentIndex - 1].item.id
            }
        } else {
            // Just clear the confirmation state but keep the item selected
            isShowingDeleteConfirmation = false
            editingItemId = nil
        }
    }
    
    func startEditingSelected(direction: EditDirection = .right) {
        editingDirection = direction
        editingItemId = selectedItemId
    }
    
    func selectNextItem() {
        // Cria uma lista plana com todos os items na ordem visual
        let flatList = buildFlattenedList(items: items)
        
        // Encontra o índice do item atual
        guard let currentFlatIndex = flatList.firstIndex(where: { $0.item.id == selectedItemId }) else {
            // Se nenhum item selecionado, seleciona o primeiro
            if !flatList.isEmpty {
                selectedItemId = flatList[0].item.id
            }
            return
        }
        
        // Seleciona o próximo item da lista plana
        let nextIndex = min(currentFlatIndex + 1, flatList.count - 1)
        selectedItemId = flatList[nextIndex].item.id
    }

    func selectPreviousItem() {
        let flatList = buildFlattenedList(items: items)
        
        guard let currentFlatIndex = flatList.firstIndex(where: { $0.item.id == selectedItemId }) else {
            if !flatList.isEmpty {
                selectedItemId = flatList[0].item.id
            }
            return
        }
        
        // Seleciona o item anterior da lista plana
        let previousIndex = max(currentFlatIndex - 1, 0)
        selectedItemId = flatList[previousIndex].item.id
    }
    
    func startEditingSelected() {
        editingItemId = selectedItemId
    }
    

    private func updateDoneStatuses(items: inout [Item]) {
        for i in items.indices {
            items[i].updateDoneStatus()
        }
    }
    
    @Published private var isUnfocusing: Bool = false


    func toggleFocusMode(forceRoot: Bool = false) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            // Caso 1: Força voltar para raiz (command+shift+enter)
            if forceRoot {
                focusedItemId = nil
                return
            }
            
            // Caso 2: Não tem foco ainda - vamos focar no item selecionado
            if focusedItemId == nil {
                focusedItemId = selectedItemId
                return
            }
            
            // Caso 3: Está com foco e:
            // - Se o item selecionado é o mesmo que está em foco -> desfoca (sobe nível)
            // - Se é um item diferente -> foca nele
            if selectedItemId == focusedItemId {
                // Tenta subir um nível
                if let parentId = findParentId(of: focusedItemId) {
                    focusedItemId = parentId
                } else {
                    // Se não tem pai, remove o foco
                    focusedItemId = nil
                }
            } else {
                // Foca no novo item selecionado
                focusedItemId = selectedItemId
            }
        }
    }
        private func findParentId(of itemId: UUID?) -> UUID? {
            guard let itemId = itemId else { return nil }
            
            func findParent(_ items: [Item]) -> UUID? {
                for item in items {
                    // Verifica se o item atual é o pai
                    if let subItems = item.subItems,
                       subItems.contains(where: { $0.id == itemId }) {
                        return item.id
                    }
                    
                    // Procura recursivamente nos subItems
                    if let subItems = item.subItems,
                       let found = findParent(subItems) {
                        return found
                    }
                }
                return nil
            }
            
            return findParent(items)
        }
        
        func commitNewItem() {
            guard !newItemText.isEmpty else { return }
            var newItem = Item(title: newItemText)
            
            // Define o nível hierárquico baseado no modo foco
            if let focusedId = focusedItemId, settings.addItemsInFocusedLevel {
                // Tenta adicionar ao item em foco
                if addItemToFocused(newItem) {
                    newItemText = ""
                    editingItemId = nil
                    return
                }
            }
            
            // Comportamento padrão: adiciona na raiz
            newItem.hierarchyLevel = 0
            
            // Usa o primeiro status de task disponível para novos itens
            if let firstTaskStatus = settings.getStatus(for: .task).first {
                newItem.status = .custom(firstTaskStatus.rawValue, colorHex: firstTaskStatus.colorHex)
            }
            
            var currentItems = items
            currentItems.append(newItem)
            updateItems(currentItems)
            newItemText = ""
            editingItemId = nil
        }
        
    private func addItemToFocused(_ newItem: Item) -> Bool {
        guard let focusedId = focusedItemId else { return false }
        
        func addToItem(in items: inout [Item]) -> Bool {
            for index in items.indices {
                if items[index].id == focusedId {
                    var parentItem = items[index]
                    
                    // Se o item pai é uma task (não tem subItems), precisamos convertê-lo para um item intermediário
                    if parentItem.isTask {
                        // Busca o primeiro status intermediário disponível (SUBPROJECT por padrão)
                        if let intermediateStatus = settings.getStatus(for: .intermediate).first {
                            parentItem.status = .custom(intermediateStatus.rawValue, colorHex: intermediateStatus.colorHex)
                        }
                    }
                    
                    // Adiciona o novo item como filho
                    try? parentItem.addSubItem(newItem)
                    parentItem.touch()
                    
                    // Atualiza o item pai na lista
                    items[index] = parentItem
                    return true
                }
                
                if var subItems = items[index].subItems {
                    if addToItem(in: &subItems) {
                        items[index].subItems = subItems
                        items[index].touch()
                        return true
                    }
                }
            }
            return false
        }
        
        var updatedItems = items
        if addToItem(in: &updatedItems) {
            items = updatedItems
            saveChanges()
            return true
        }
        return false
    }

    private func updateItemInHierarchy(itemId: UUID, action: (inout Item) -> Void) {
        // Função recursiva para atualizar item em qualquer nível
        func update(in items: inout [Item]) -> Bool {
            for index in items.indices {
                if items[index].id == itemId {
                    action(&items[index])
                    return true
                }
                
                if var subItems = items[index].subItems {
                    if update(in: &subItems) {
                        items[index].subItems = subItems
                        return true
                    }
                }
            }
            return false
        }
        
        // Atualiza o item em qualquer nível da hierarquia
        var updatedItems = items
        if update(in: &updatedItems) {
            items = updatedItems
        }
    }
    
    func startNewItem() {
        newItemText = ""
        editingItemId = nil
    }
    
    private func updateItemWhenEmpty(item: inout Item) {
        if item.subItems?.isEmpty == true || item.subItems == nil {
            // Se não tem mais filhos, volta a ser uma task normal
            item.subItems = nil // Limpa explicitamente
            // Usamos o primeiro status disponível da categoria task
            if let firstTaskStatus = settings.getStatus(for: .task).first {
                item.status = .custom(firstTaskStatus.rawValue, colorHex: firstTaskStatus.colorHex)
            } else {
                // Caso extremo onde não há status de task disponível, cria um TODO padrão
                item.status = .custom("TODO", colorHex: "#007AFF")
            }
            item.touch()
        }
    }
    
    // Função recursiva para atualizar níveis hierárquicos
    private func updateHierarchyLevels(items: [Item], parentLevel: Int) -> [Item] {
        return items.map { item in
            var updatedItem = item
            // Atualiza o nível hierárquico
            updatedItem.hierarchyLevel = parentLevel
            
            // Só atualiza o status se o item tiver filhos
            // Items sem filhos mantêm seu status original
            if !updatedItem.isTask {
                // Não força atualização pois é apenas uma atualização de consistência
                updatedItem.updateStatusBasedOnHierarchy(settings: settings, forceUpdate: false)
            }
            
            // Processa os filhos recursivamente
            if var subItems = updatedItem.subItems {
                updatedItem.subItems = updateHierarchyLevels(items: subItems, parentLevel: parentLevel + 1)
            }
            
            return updatedItem
        }
    }

    private func updateEmptyStatuses(items: inout [Item]) {
        for index in items.indices {
            if var subItems = items[index].subItems {
                updateEmptyStatuses(items: &subItems)
                items[index].subItems = subItems
                
                // Se tem filhos, atualiza o status baseado na hierarquia
                if !items[index].isTask {
                    // Não força atualização pois é apenas uma atualização de consistência
                    items[index].updateStatusBasedOnHierarchy(settings: settings, forceUpdate: false)
                }
            }
        }
    }

        // Função para atualizar toda a árvore
    private func updateAllHierarchyLevels() {
        var updatedItems = updateHierarchyLevels(items: items, parentLevel: 0)
        updateEmptyStatuses(items: &updatedItems)
        updateDoneStatuses(items: &updatedItems)
        items = updatedItems
    }
    
    func dedentSelectedItem() {
        let flatList = buildFlattenedList(items: items)
        guard let selectedId = selectedItemId,
              let currentItemInfo = flatList.first(where: { $0.item.id == selectedId }) else {
            showShakeAnimation()
            return
        }
        
        func findParentInfo(in items: inout [Item]) -> (item: Item, currentParent: Item)? {
            for index in items.indices {
                if let subItems = items[index].subItems,
                   let childIndex = subItems.firstIndex(where: { $0.id == selectedId }) {
                    var parent = items[index]
                    var child = parent.subItems!.remove(at: childIndex)
                    
                    // Atualiza o status do pai se ele ficar sem filhos
                    updateItemWhenEmpty(item: &parent)
                    parent.touch()
                    
                    child.touch()
                    // Força atualização pois o item está sendo movido
                    child.updateStatusBasedOnHierarchy(settings: settings, forceUpdate: true)
                    
                    items[index] = parent
                    return (child, parent)
                }
                
                if var subItems = items[index].subItems {
                    if let found = findParentInfo(in: &subItems) {
                        items[index].subItems = subItems
                        // Não força atualização pois este item não está sendo movido
                        items[index].updateStatusBasedOnHierarchy(settings: settings, forceUpdate: false)
                        return found
                    }
                }
            }
            return nil
        }
        
        var updatedItems = items
        if let (removedItem, currentParent) = findParentInfo(in: &updatedItems) {
            func addToNewParent(item: Item, in items: inout [Item], parentId: UUID) -> Bool {
                for index in items.indices {
                    if items[index].id == parentId {
                        var newParent = items[index]
                        try? newParent.addSubItem(removedItem)
                        newParent.updateStatusBasedOnHierarchy(settings: settings)
                        items[index] = newParent
                        return true
                    }
                    
                    if var subItems = items[index].subItems {
                        if addToNewParent(item: item, in: &subItems, parentId: parentId) {
                            items[index].subItems = subItems
                            items[index].updateStatusBasedOnHierarchy(settings: settings)
                            return true
                        }
                    }
                }
                return false
            }
            
            if let grandParentInfo = flatList.first(where: {
                if let subItems = $0.item.subItems {
                    return subItems.contains(where: { $0.id == currentParent.id })
                }
                return false
            }) {
                _ = addToNewParent(item: removedItem, in: &updatedItems, parentId: grandParentInfo.item.id)
            } else {
                var rootItem = removedItem
                rootItem.hierarchyLevel = 0
                rootItem.updateStatusBasedOnHierarchy(settings: settings)
                updatedItems.append(rootItem)
            }
            
            items = updatedItems
            selectedItemId = removedItem.id
            updateAllHierarchyLevels()
            saveChanges()
        } else {
            showShakeAnimation()
        }
    }

    // Updated indent logic
    func indentSelectedItem() {
        let flatList = buildFlattenedList(items: items)
        guard let selectedId = selectedItemId,
              let currentItemIndex = flatList.firstIndex(where: { $0.item.id == selectedId }) else {
            showShakeAnimation()
            return
        }
        
        let currentItem = flatList[currentItemIndex]
        
        var potentialParentIndex = currentItemIndex - 1
        while potentialParentIndex >= 0 {
            let potentialParent = flatList[potentialParentIndex]
            if potentialParent.level == currentItem.level {
                break
            }
            potentialParentIndex -= 1
        }
        
        guard potentialParentIndex >= 0 else {
            showShakeAnimation()
            return
        }
        
        // Função auxiliar para encontrar e remover um item
        func findAndRemoveItem(in items: inout [Item], id: UUID) -> Item? {
            if let index = items.firstIndex(where: { $0.id == id }) {
                return items.remove(at: index)
            }
            
            for i in items.indices {
                if var subItems = items[i].subItems {
                    if let found = findAndRemoveItem(in: &subItems, id: id) {
                        items[i].subItems = subItems
                        // Se o item ficou sem filhos, atualiza seu status
                        if subItems.isEmpty {
                            updateItemWhenEmpty(item: &items[i])
                        }
                        return found
                    }
                }
            }
            
            return nil
        }
        
        func indent(in items: inout [Item], parentId: UUID) -> Bool {
            for index in items.indices {
                if items[index].id == selectedId {
                    var itemToMove = items.remove(at: index)
                    itemToMove.touch()
                    // Força atualização pois o item está sendo movido
                    itemToMove.updateStatusBasedOnHierarchy(settings: settings, forceUpdate: true)
                    return true
                }
                
                if items[index].id == parentId {
                    if items[index].subItems == nil {
                        items[index].subItems = []
                    }
                    
                    if let removedItem = findAndRemoveItem(in: &items, id: selectedId) {
                        var itemToAdd = removedItem
                        itemToAdd.hierarchyLevel = items[index].hierarchyLevel + 1
                        // Força atualização pois o item está sendo movido
                        itemToAdd.updateStatusBasedOnHierarchy(settings: settings, forceUpdate: true)
                        try? items[index].addSubItem(itemToAdd)
                        
                        // Não força atualização do pai pois ele não está sendo movido
                        items[index].updateStatusBasedOnHierarchy(settings: settings, forceUpdate: false)
                        items[index].touch()
                    }
                    
                    return true
                }
                
                if var subItems = items[index].subItems {
                    if indent(in: &subItems, parentId: parentId) {
                        items[index].subItems = subItems
                        // Não força atualização pois este item não está sendo movido
                        items[index].updateStatusBasedOnHierarchy(settings: settings, forceUpdate: false)
                        return true
                    }
                }
            }
            return false
        }
        
        let parentItem = flatList[potentialParentIndex]
        var updatedItems = items
        if indent(in: &updatedItems, parentId: parentItem.item.id) {
            items = updatedItems
            updateAllHierarchyLevels() // Garante que toda a árvore está consistente
            saveChanges()
        }
    }
    
    
    // MARK: - Visual Feedback

    private func showShakeAnimation() {
        guard !shakeSelected else { return } // Previne múltiplas animações
        shakeSelected = true
    }
    
    func buildFlattenedList(items: [Item]) -> [FlattenedItem] {
        // If we have a focused item, return only it and its children
        if let focusedId = focusedItemId {
            return buildFocusedList(items: items, focusedId: focusedId)
        }
        
        var result: [FlattenedItem] = []
        
        for item in items {
            result.append(FlattenedItem(item: item, level: 0))
            
            // Only add children if the item is not collapsed
            if let subItems = item.subItems, !item.isCollapsed {
                result.append(contentsOf: buildFlattenedSubItems(items: subItems, level: 1))
            }
        }
        
        return result
    }
    
    // Modified buildFlattenedSubItems to respect collapsed state
    private func buildFlattenedSubItems(items: [Item], level: Int) -> [FlattenedItem] {
        var result: [FlattenedItem] = []
        
        for item in items {
            result.append(FlattenedItem(item: item, level: level))
            
            // Only add children if the item is not collapsed
            if let subItems = item.subItems, !item.isCollapsed {
                result.append(contentsOf: buildFlattenedSubItems(items: subItems, level: level + 1))
            }
        }
        
        return result
    }
    
    // Handle keyboard navigation for breadcrumb
    func handleBreadcrumbNavigation(direction: Int) {
        guard let path = buildBreadcrumbPath() else { return }
        guard let currentIndex = path.firstIndex(where: { $0.id == focusedItemId }) else { return }
        
        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < path.count else { return }
        
        focusedItemId = path[newIndex].id
    }
    
    func buildBreadcrumbPath() -> [BreadcrumbItem]? {
        guard let focusedId = focusedItemId else { return nil }
        
        var path: [BreadcrumbItem] = []
        
        func findPath(in items: [Item], level: Int = 0) -> Bool {
            for item in items {
                if item.id == focusedId {
                    path.append(BreadcrumbItem(
                        id: item.id,
                        title: item.title,
                        status: item.status,
                        level: level
                    ))
                    return true
                }
                
                if let subItems = item.subItems {
                    if findPath(in: subItems, level: level + 1) {
                        path.append(BreadcrumbItem(
                            id: item.id,
                            title: item.title,
                            status: item.status,
                            level: level
                        ))
                        return true
                    }
                }
            }
            return false
        }
        
        _ = findPath(in: items)
        return path.reversed()
    }
    
    @Published var isBreadcrumbFocused: Bool = false
    @Published var selectedBreadcrumbIndex: Int = -1
    @Published var pendingBreadcrumbSelection: UUID? = nil // Novo

    func toggleBreadcrumbFocus() {
        guard focusedItemId != nil else { return }
        
        if !isBreadcrumbFocused {
            if let path = buildBreadcrumbPath() {
                isBreadcrumbFocused = true
                selectedBreadcrumbIndex = path.count - 1
                pendingBreadcrumbSelection = path[path.count - 1].id
            }
        } else {
            isBreadcrumbFocused = false
            selectedBreadcrumbIndex = -1
            pendingBreadcrumbSelection = nil
        }
    }

    func navigateBreadcrumb(direction: Int) {
        guard isBreadcrumbFocused,
              let path = buildBreadcrumbPath() else { return }
        
        let newIndex = selectedBreadcrumbIndex + direction
        guard newIndex >= 0 && newIndex < path.count else { return }
        
        selectedBreadcrumbIndex = newIndex
        pendingBreadcrumbSelection = path[newIndex].id // Apenas atualiza a seleção pendente
    }

    func commitBreadcrumbNavigation() {
        if let pendingId = pendingBreadcrumbSelection {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                focusedItemId = pendingId
            }
            toggleBreadcrumbFocus() // Sai do modo de navegação após confirmar
        }
    }
}

extension TaskListViewModel {
    /// Estrutura auxiliar para operações de hierarquia
    private struct ItemPath {
        let parentIndex: Int?
        let index: Int
        let level: Int
    }
    
    func toggleSelectedItemCollapse() {
        guard let selectedId = selectedItemId else { return }
        
        func toggleCollapse(in items: inout [Item]) -> Bool {
            for index in items.indices {
                if items[index].id == selectedId {
                    items[index].isCollapsed.toggle()
                    items[index].touch()
                    return true
                }
                
                if var subItems = items[index].subItems {
                    if toggleCollapse(in: &subItems) {
                        items[index].subItems = subItems
                        return true
                    }
                }
            }
            return false
        }
        
        var updatedItems = items
        if toggleCollapse(in: &updatedItems) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                items = updatedItems
                saveChanges()
            }
        }
    }
    
    // Toggle collapse state of all items
    func toggleAllCollapsed() {
        allCollapsed.toggle() // Toggle o estado global
        
        // Recursive function to set collapse state
        func setCollapseState(in items: inout [Item], collapsed: Bool) {
            for index in items.indices {
                if items[index].subItems != nil && !items[index].subItems!.isEmpty {
                    items[index].isCollapsed = collapsed
                    items[index].touch()
                    
                    if var subItems = items[index].subItems {
                        setCollapseState(in: &subItems, collapsed: collapsed)
                        items[index].subItems = subItems
                    }
                }
            }
        }
        
        var updatedItems = items
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            setCollapseState(in: &updatedItems, collapsed: allCollapsed)
            items = updatedItems
        }
    }
    
    // Collapse all items
    func collapseAll() {
        // Recursive function to collapse all items
        func collapseItems(in items: inout [Item]) {
            for index in items.indices {
                if items[index].subItems != nil && !items[index].subItems!.isEmpty {
                    items[index].isCollapsed = true
                    items[index].touch()
                    
                    if var subItems = items[index].subItems {
                        collapseItems(in: &subItems)
                        items[index].subItems = subItems
                    }
                }
            }
        }
        
        var updatedItems = items
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            collapseItems(in: &updatedItems)
            items = updatedItems
        }
    }
    
    // Expand all items
    func expandAll() {
        // Recursive function to expand all items
        func expandItems(in items: inout [Item]) {
            for index in items.indices {
                if items[index].subItems != nil && !items[index].subItems!.isEmpty {
                    items[index].isCollapsed = false
                    items[index].touch()
                    
                    if var subItems = items[index].subItems {
                        expandItems(in: &subItems)
                        items[index].subItems = subItems
                    }
                }
            }
        }
        
        var updatedItems = items
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            expandItems(in: &updatedItems)
            items = updatedItems
        }
    }
    
    private func buildFocusedList(items: [Item], focusedId: UUID) -> [FlattenedItem] {
        // Se estamos desfocando (subindo nível), procuramos o pai
        if isUnfocusing {
            func findFocusedItemAndParent(_ items: [Item]) -> (Item, Item?)? {
                for item in items {
                    if item.id == focusedId {
                        return (item, nil)
                    }
                    
                    if let subItems = item.subItems {
                        for subItem in subItems {
                            if subItem.id == focusedId {
                                return (subItem, item)
                            }
                            
                            if let (found, parent) = findFocusedItemAndParent([subItem]) {
                                return (found, parent ?? item)
                            }
                        }
                    }
                }
                return nil
            }
            
            if let (_, parent) = findFocusedItemAndParent(items), let parentActual = parent {
                var result = [FlattenedItem(item: parentActual, level: 0)]
                if let subItems = parentActual.subItems {
                    result.append(contentsOf: buildFlattenedSubItems(items: subItems, level: 1))
                }
                return result
            }
        }
        
        // Se estamos focando pela primeira vez ou não encontramos o pai, mostra o item focado
        for item in items {
            if item.id == focusedId {
                var result = [FlattenedItem(item: item, level: 0)]
                if let subItems = item.subItems {
                    result.append(contentsOf: buildFlattenedSubItems(items: subItems, level: 1))
                }
                return result
            }
            
            if let subItems = item.subItems {
                let focusedList = buildFocusedList(items: subItems, focusedId: focusedId)
                if !focusedList.isEmpty {
                    let baseLevel = focusedList[0].level
                    return focusedList.map { FlattenedItem(item: $0.item, level: $0.level - baseLevel) }
                }
            }
        }
        
        return []
    }
    
    /// Encontra o caminho do item selecionado na hierarquia
    private func findSelectedItemPath() -> ItemPath? {
        guard let selectedId = selectedItemId else { return nil }
        
        func findInItems(_ items: [Item], parentIndex: Int?, level: Int) -> ItemPath? {
            for (index, item) in items.enumerated() {
                if item.id == selectedId {
                    return ItemPath(parentIndex: parentIndex, index: index, level: level)
                }
                if let subItems = item.subItems,
                   let found = findInItems(subItems, parentIndex: index, level: level + 1) {
                    return found
                }
            }
            return nil
        }
        
        return findInItems(items, parentIndex: nil, level: 0)
    }
    
    /// Move a hierarquia selecionada para cima
    func moveSelectedHierarchyUp() {
        let flatList = buildFlattenedList(items: items)
        guard let selectedId = selectedItemId,
              let currentItem = flatList.first(where: { $0.item.id == selectedId }) else { return }
        
        func moveUp(in items: inout [Item]) -> Bool {
            for parentIndex in items.indices {
                if items[parentIndex].id == selectedId && parentIndex > 0 {
                    items.swapAt(parentIndex, parentIndex - 1)
                    items[parentIndex].touch()
                    items[parentIndex - 1].touch()
                    return true
                }
                
                if var subItems = items[parentIndex].subItems {
                    if moveUp(in: &subItems) {
                        items[parentIndex].subItems = subItems
                        items[parentIndex].touch()
                        return true
                    }
                }
            }
            return false
        }
        
        var updatedItems = items
        if moveUp(in: &updatedItems) {
            items = updatedItems
            saveChanges()
        }
    }

    func moveSelectedHierarchyDown() {
        let flatList = buildFlattenedList(items: items)
        guard let selectedId = selectedItemId,
              let currentItem = flatList.first(where: { $0.item.id == selectedId }) else { return }
        
        func moveDown(in items: inout [Item]) -> Bool {
            for parentIndex in items.indices {
                if items[parentIndex].id == selectedId && parentIndex < items.count - 1 {
                    items.swapAt(parentIndex, parentIndex + 1)
                    items[parentIndex].touch()
                    items[parentIndex + 1].touch()
                    return true
                }
                
                if var subItems = items[parentIndex].subItems {
                    if moveDown(in: &subItems) {
                        items[parentIndex].subItems = subItems
                        items[parentIndex].touch()
                        return true
                    }
                }
            }
            return false
        }
        
        var updatedItems = items
        if moveDown(in: &updatedItems) {
            items = updatedItems
            saveChanges()
        }
    }
}
