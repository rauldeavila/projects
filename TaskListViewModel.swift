import SwiftUI

struct FlattenedItem: Identifiable {
    let id = UUID()
    let item: Item
    let level: Int
}

/// View model to manage the task list state
class TaskListViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var editingItemId: UUID?
    @Published var newItemText: String = ""
    @Published var selectedItemId: UUID?
    @Published var editingDirection: EditDirection = .right
    @Published var shakeSelected: Bool = false
    @Published var focusedItemId: UUID?
    @Published private var allCollapsed: Bool = false
    @Published var isShowingDeleteConfirmation: Bool = false
    @Published var deleteConfirmationOption: DeleteOption = .yes
    
    // Status groups for cycling
    private let taskStatuses: [ItemStatus] = ItemStatus.allCases.filter { !$0.isProjectStatus }

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
    
    func deleteSelectedItem() {
        guard let selectedId = selectedItemId else { return }
        
        func deleteItem(in items: inout [Item]) -> Bool {
            if let index = items.firstIndex(where: { $0.id == selectedId }) {
                items.remove(at: index)
                return true
            }
            
            for index in items.indices {
                if var subItems = items[index].subItems {
                    if deleteItem(in: &subItems) {
                        items[index].subItems = subItems
                        if subItems.isEmpty {
                            items[index].status = .todo
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
            editingItemId = nil
            isShowingDeleteConfirmation = false
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
    
    func updateItemTitle(_ id: UUID, newTitle: String) {
        // Função recursiva auxiliar para atualizar título em qualquer nível
        func updateTitle(in items: inout [Item]) -> Bool {
            for index in items.indices {
                if items[index].id == id {
                    items[index].title = newTitle
                    items[index].touch()
                    return true
                }
                
                // Procura recursivamente nos subitems
                if var subItems = items[index].subItems {
                    if updateTitle(in: &subItems) {
                        items[index].subItems = subItems
                        return true
                    }
                }
            }
            return false
        }
        
        // Atualiza o item em qualquer nível da hierarquia
        var updatedItems = items
        if updateTitle(in: &updatedItems) {
            items = updatedItems
        }
        editingItemId = nil
    }
    
    func cycleSelectedItemStatus(direction: Int = 1) {
        guard let selectedId = selectedItemId else { return }
        
        updateItemInHierarchy(itemId: selectedId) { item in

            if item.isProject || item.isSubProject {
                return
            }
            
            let statuses = taskStatuses
            
            // Find current status index
            if let statusIndex = statuses.firstIndex(of: item.status) {
                let nextIndex = (statusIndex + direction + statuses.count) % statuses.count
                item.status = statuses[nextIndex]
            } else {
                item.status = statuses[0]
            }
            
            item.touch()
        }
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
    
    func addItem(_ title: String) {
        let newItem = Item(title: title)
        items.append(newItem)
    }
    
    func startNewItem() {
        newItemText = ""
        editingItemId = nil
    }
    
    func commitNewItem() {
        guard !newItemText.isEmpty else { return }
        addItem(newItemText)
        newItemText = ""
        editingItemId = nil  // Garante que saímos do modo de edição
    }
    
    // MARK: - Indentation Functions
        
    func indentSelectedItem() {
        let flatList = buildFlattenedList(items: items)
        guard let selectedId = selectedItemId,
              let currentItemIndex = flatList.firstIndex(where: { $0.item.id == selectedId }) else {
            showShakeAnimation()
            return
        }
        
        let currentItem = flatList[currentItemIndex]
        
        // Não permite indentar se for um SUBPROJ
        if currentItem.item.status == .subProj {
            showShakeAnimation()
            return
        }
        
        
        // Procura o item pai adequado (primeiro item acima no mesmo nível)
        var potentialParentIndex = currentItemIndex - 1
        while potentialParentIndex >= 0 {
            let potentialParent = flatList[potentialParentIndex]
            if potentialParent.level == currentItem.level {
                // Encontramos o pai adequado
                break
            }
            potentialParentIndex -= 1
        }
        
        func hasSubProjectInHierarchy(_ item: Item) -> Bool {
            if item.status == .subProj {
                return true
            }
            return item.subItems?.contains(where: { hasSubProjectInHierarchy($0) }) ?? false
        }
        
        if hasSubProjectInHierarchy(currentItem.item) {
            showShakeAnimation()
            return
        }
        
        // Se não encontramos um pai adequado ou é o primeiro item, não podemos indentar
        guard potentialParentIndex >= 0 else {
            showShakeAnimation()
            return
        }
        
        let parentItem = flatList[potentialParentIndex]
        
        // Verifica limite de nesting
        let newLevel = parentItem.level + 1
        guard newLevel < Item.maxNestingLevel else {
            showShakeAnimation()
            return
        }
        
        // Função recursiva para indentar em qualquer nível
        func indent(in items: inout [Item], parentId: UUID) -> Bool {
            for index in items.indices {
                // Verifica se encontramos o item para indentar
                if items[index].id == selectedId {
                    // Remove o item atual
                    var itemToMove = items.remove(at: index)
                    
                    // Se o item sendo movido é um projeto (tem filhos) e está indo para nível 1
                    // então ele deve se tornar um subprojeto
                    if !itemToMove.isTask && parentItem.level == 0 {
                        itemToMove.status = .subProj
                        itemToMove.touch()
                    }
                    
                    return true
                }
                
                // Se encontramos o pai
                if items[index].id == parentId {
                    // Atualiza o status do novo pai se necessário
                    if items[index].isTask {
                        // Se estamos no nível 0, o pai vira PROJ
                        // Se estamos no nível 1, o pai vira SUBPROJ
                        items[index].status = parentItem.level == 0 ? .proj : .subProj
                        items[index].touch()
                    }
                    
                    // Adiciona o item como filho
                    if items[index].subItems == nil {
                        items[index].subItems = []
                    }
                    
                    // Guarda o item removido para adicionar depois
                    if let removedItem = findAndRemoveItem(in: &items, id: selectedId) {
                        var itemToAdd = removedItem
                        // Se o item sendo movido é um projeto (tem filhos) e está indo para nível 1
                        // então ele deve se tornar um subprojeto
                        if !itemToAdd.isTask && parentItem.level == 0 {
                            itemToAdd.status = .subProj
                            itemToAdd.touch()
                        }
                        try? items[index].addSubItem(itemToAdd)
                    }
                    
                    return true
                }
                
                // Procura recursivamente nos subitems
                if var subItems = items[index].subItems {
                    if indent(in: &subItems, parentId: parentId) {
                        items[index].subItems = subItems
                        return true
                    }
                }
            }
            return false
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
                        return found
                    }
                }
            }
            
            return nil
        }
        
        var updatedItems = items
        if indent(in: &updatedItems, parentId: parentItem.item.id) {
            items = updatedItems
        }
    }

    func dedentSelectedItem() {
        let flatList = buildFlattenedList(items: items)
        guard let selectedId = selectedItemId,
              let currentItemInfo = flatList.first(where: { $0.item.id == selectedId }) else {
            showShakeAnimation()
            return
        }

        // Função recursiva para encontrar e remover o item de sua posição atual
        // Retorna o item removido e seu pai
        func findParentInfo(in items: inout [Item]) -> (item: Item, currentParent: Item)? {
            for index in items.indices {
                if let subItems = items[index].subItems,
                   let childIndex = subItems.firstIndex(where: { $0.id == selectedId }) {
                    // Encontramos o item e seu pai
                    var parent = items[index]
                    var child = parent.subItems!.remove(at: childIndex)
                    
                    if child.status == .subProj {
                        child.status = .proj
                        child.touch()
                    }
                    
                    // Se o pai ficou sem filhos, volta para task
                    if parent.subItems!.isEmpty {
                        parent.status = .todo
                    }
                    
                    items[index] = parent
                    return (child, parent)
                }
                
                // Procura recursivamente nos subitems
                if var subItems = items[index].subItems {
                    if let found = findParentInfo(in: &subItems) {
                        items[index].subItems = subItems
                        return found
                    }
                }
            }
            return nil
        }

        var updatedItems = items
        if let (removedItem, currentParent) = findParentInfo(in: &updatedItems) {
            // Função para adicionar o item ao novo pai
            func addToNewParent(item: Item, in items: inout [Item], parentId: UUID) -> Bool {
                for index in items.indices {
                    if items[index].id == parentId {
                        // Encontramos o novo pai (o avô), adicionamos o item como seu filho
                        try? items[index].addSubItem(removedItem)
                        return true
                    }
                    
                    // Procura recursivamente nos subitems
                    if var subItems = items[index].subItems {
                        if addToNewParent(item: item, in: &subItems, parentId: parentId) {
                            items[index].subItems = subItems
                            return true
                        }
                    }
                }
                return false
            }
            
            // Procura o pai do pai (avô) na lista plana
            if let grandParentInfo = flatList.first(where: {
                if let subItems = $0.item.subItems {
                    return subItems.contains(where: { $0.id == currentParent.id })
                }
                return false
            }) {
                // Adiciona o item removido como filho do avô
                _ = addToNewParent(item: removedItem, in: &updatedItems, parentId: grandParentInfo.item.id)
                items = updatedItems
                selectedItemId = removedItem.id
            } else {
                // Se não encontrou o avô, então o pai é de nível 0
                // Neste caso, adicionamos o item na raiz
                updatedItems.append(removedItem)
                items = updatedItems
                selectedItemId = removedItem.id
            }
        } else {
            showShakeAnimation()
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
}

extension TaskListViewModel {
    /// Estrutura auxiliar para operações de hierarquia
    private struct ItemPath {
        let parentIndex: Int?
        let index: Int
        let level: Int
    }
    
    func toggleFocusMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if focusedItemId == selectedItemId {
                focusedItemId = nil
            } else {
                focusedItemId = selectedItemId
            }
        }
    }
    
    func toggleSelectedItemCollapse() {
        guard let selectedId = selectedItemId else { return }
        
        // Recursive function to find and toggle the selected item
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
        for item in items {
            if item.id == focusedId {
                // Found the focused item, return it and its children
                var result = [FlattenedItem(item: item, level: 0)]
                if let subItems = item.subItems {
                    result.append(contentsOf: buildFlattenedSubItems(items: subItems, level: 1))
                }
                return result
            }
            
            // Look in subitems
            if let subItems = item.subItems {
                let focusedList = buildFocusedList(items: subItems, focusedId: focusedId)
                if !focusedList.isEmpty {
                    // Se encontramos em um subnível, retornamos ajustando o nível para começar do 0
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
        
        // Função recursiva para mover item em qualquer nível
        func moveUp(in items: inout [Item]) -> Bool {
            for parentIndex in items.indices {
                if items[parentIndex].id == selectedId && parentIndex > 0 {
                    // Move no nível atual
                    items.swapAt(parentIndex, parentIndex - 1)
                    return true
                }
                
                if var subItems = items[parentIndex].subItems {
                    if moveUp(in: &subItems) {
                        items[parentIndex].subItems = subItems
                        return true
                    }
                }
            }
            return false
        }
        
        var updatedItems = items
        if moveUp(in: &updatedItems) {
            items = updatedItems
        }
    }

    /// Move a hierarquia selecionada para baixo
    func moveSelectedHierarchyDown() {
        let flatList = buildFlattenedList(items: items)
        guard let selectedId = selectedItemId,
              let currentItem = flatList.first(where: { $0.item.id == selectedId }) else { return }
        
        // Função recursiva para mover item em qualquer nível
        func moveDown(in items: inout [Item]) -> Bool {
            for parentIndex in items.indices {
                if items[parentIndex].id == selectedId && parentIndex < items.count - 1 {
                    // Move no nível atual
                    items.swapAt(parentIndex, parentIndex + 1)
                    return true
                }
                
                if var subItems = items[parentIndex].subItems {
                    if moveDown(in: &subItems) {
                        items[parentIndex].subItems = subItems
                        return true
                    }
                }
            }
            return false
        }
        
        var updatedItems = items
        if moveDown(in: &updatedItems) {
            items = updatedItems
        }
    }
}
