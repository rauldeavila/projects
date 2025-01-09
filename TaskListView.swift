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
    private let taskStatuses: [ItemStatus] = [.todo, .doing, .someday, .maybe, .future, .done]
    private let projectStatuses: [ItemStatus] = [.proj, .subProj]
    
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
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].title = newTitle
            items[index].touch()
        }
        editingItemId = nil
    }
    
    func cycleSelectedItemStatus(direction: Int = 1) {
        guard let selectedId = selectedItemId else { return }
        
        updateItemInHierarchy(itemId: selectedId) { item in
            // Choose appropriate status array based on item type
            let statuses = item.isProject || item.isSubProject ? projectStatuses : taskStatuses
            
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
        shakeSelected = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.shakeSelected = false
        }
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

/// Main view for the task list
struct TaskListView: View {
    @StateObject private var viewModel = TaskListViewModel()
    @FocusState private var isNewItemFieldFocused: Bool
    @SceneStorage("zoomLevel") private var zoomLevel: Double = 1.0
    
    private let minZoom: Double = 0.5
    private let maxZoom: Double = 2.0
    private let zoomStep: Double = 0.1
    
    private let baseTitleSize: Double = 13.0
    private let baseStatusSize: Double = 11.0
    private let baseNewItemSize: Double = 13.0
    


    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.buildFlattenedList(items: viewModel.items), id: \.item.id) { itemInfo in
                            ItemRowView(
                                id: itemInfo.item.id,
                                viewModel: viewModel,
                                item: itemInfo.item,
                                isSelected: viewModel.selectedItemId == itemInfo.item.id,
                                isEditing: viewModel.editingItemId == itemInfo.item.id,
                                editingDirection: viewModel.editingDirection,
                                onTitleChange: { newTitle in
                                    viewModel.updateItemTitle(itemInfo.item.id, newTitle: newTitle)
                                    isNewItemFieldFocused = true
                                },
                                fontSize: baseTitleSize * zoomLevel,
                                statusFontSize: baseStatusSize * zoomLevel,
                                level: itemInfo.level,
                                onToggleCollapse: {
                                    if itemInfo.item.id == viewModel.selectedItemId {
                                        viewModel.toggleSelectedItemCollapse()
                                    }
                                },
                                isNewItemFieldFocused: _isNewItemFieldFocused
                            )
                            .background(viewModel.selectedItemId == itemInfo.item.id ? Color.accentColor.opacity(0.5) : Color.clear)
                            .modifier(ShakeEffect(shake: itemInfo.item.id == viewModel.selectedItemId && viewModel.shakeSelected))
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                        
                        if viewModel.focusedItemId != nil {
                            HStack {
                                Text("Focus Mode")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                
                                Button("Exit") {
                                    viewModel.focusedItemId = nil
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 12))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                        }
                        
                        Group {
                            Button("") { viewModel.cycleSelectedItemStatus(direction: -1) }
                                .keyboardShortcut(.downArrow, modifiers: [.command])
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") { viewModel.cycleSelectedItemStatus(direction: 1) }
                                .keyboardShortcut(.upArrow, modifiers: [.command])
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") { viewModel.startEditingSelected(direction: .left) }
                                .keyboardShortcut(.leftArrow, modifiers: [.command])
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") { viewModel.startEditingSelected(direction: .right) }
                                .keyboardShortcut(.rightArrow, modifiers: [.command])
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") {
                                zoomLevel = min(maxZoom, zoomLevel + zoomStep)
                            }
                            .keyboardShortcut(KeyboardShortcut("=", modifiers: .command))
                            .opacity(0)
                            .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") {
                                zoomLevel = max(minZoom, zoomLevel - zoomStep)
                            }
                            .keyboardShortcut(KeyboardShortcut("-", modifiers: .command))
                            .opacity(0)
                            .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") { viewModel.moveSelectedHierarchyUp() }
                                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") { viewModel.moveSelectedHierarchyDown() }
                                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") { viewModel.toggleFocusMode() }
                                .keyboardShortcut(.return, modifiers: [.command])
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") { viewModel.toggleSelectedItemCollapse() }
                                .keyboardShortcut(KeyEquivalent("."), modifiers: .command)
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") { viewModel.toggleAllCollapsed() }
                                .keyboardShortcut(KeyEquivalent("."), modifiers: [.command, .shift])
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                        } // group
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if viewModel.editingItemId == nil {
                    TextField("New item...", text: $viewModel.newItemText)
                        .textFieldStyle(.plain)
                        .font(.system(size: baseNewItemSize * zoomLevel))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black)
                        .focused($isNewItemFieldFocused)
                        .onSubmit {
                            viewModel.commitNewItem()
                            isNewItemFieldFocused = true
                        }
                }
            }
            .background(Color(.textBackgroundColor))
            .onKeyPress(.upArrow) {
                viewModel.selectPreviousItem()
                if let selectedId = viewModel.selectedItemId {
                    proxy.scrollTo(selectedId, anchor: .center)
                }
                return .handled
            }
            .onKeyPress(.downArrow) {
                viewModel.selectNextItem()
                if let selectedId = viewModel.selectedItemId {
                    proxy.scrollTo(selectedId, anchor: .center)
                }
                return .handled
            }
            .onKeyPress(.space) {
                if viewModel.editingItemId == nil && !isNewItemFieldFocused {
                    viewModel.startNewItem()
                    isNewItemFieldFocused = true
                    return .handled
                }
                return .ignored
            }
            .onKeyPress("]") {
                viewModel.indentSelectedItem()
                return .handled
            }
            .onKeyPress("[") {
                viewModel.dedentSelectedItem()
                return .handled
            }
        }
    }
}

// Custom NSTextField wrapper that gives us more control
struct CustomTextField: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    let cursorPosition: TaskListViewModel.EditDirection
    let fontSize: Double
    var onEmptyDelete: (() -> Void)? = nil
    
    @State private var hasPositionedCursor = false
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CustomTextField
        
        init(_ parent: CustomTextField) {
            self.parent = parent
            super.init()
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                control.window?.makeFirstResponder(nil)
                DispatchQueue.main.async {
                    self.parent.onSubmit()
                }
                return true
            }
            
            // Handle delete/backspace when text is empty
            if (commandSelector == #selector(NSResponder.deleteBackward(_:)) ||
                commandSelector == #selector(NSResponder.deleteForward(_:))) &&
                textView.string.isEmpty {
                parent.onEmptyDelete?()
                return true
            }
            
            return false
        }
    }
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        textField.drawsBackground = false
        textField.isBezeled = false
        textField.font = .systemFont(ofSize: fontSize)
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        nsView.font = .systemFont(ofSize: fontSize)
        
        if !hasPositionedCursor {
            DispatchQueue.main.async {
                guard let window = nsView.window else { return }
                window.makeFirstResponder(nsView)
                
                if let fieldEditor = window.fieldEditor(true, for: nsView) as? NSTextView {
                    switch cursorPosition {
                    case .left:
                        fieldEditor.selectedRange = NSRange(location: 0, length: 0)
                    case .right:
                        fieldEditor.selectedRange = NSRange(location: text.count, length: 0)
                    }
                }
                hasPositionedCursor = true
            }
        }
    }
}

struct TaskCounterView: View {
    let completed: Int
    let total: Int
    let fontSize: Double
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Text("\(completed)/\(total)")
            .font(.system(size: fontSize, design: .monospaced))
            .foregroundColor(completed == total && total > 0 ? .green : .white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.black)
            .cornerRadius(4)
            .scaleEffect(scale)
            .onChange(of: completed) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    scale = 1.2
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        scale = 1.0
                    }
                }
            }
    }
}

// Agora vamos atualizar o ItemRowView para incluir o contador
struct ItemRowView: View {
    let id: UUID
    let viewModel: TaskListViewModel
    let item: Item
    let isSelected: Bool
    let isEditing: Bool
    let editingDirection: TaskListViewModel.EditDirection
    let onTitleChange: (String) -> Void
    let fontSize: Double
    let statusFontSize: Double
    let level: Int
    let onToggleCollapse: () -> Void
    
    @State private var editingTitle: String = ""
    @State private var statusScale: Double = 1.0
    @FocusState private var isDeleteConfirmationFocused: Bool
    @FocusState var isNewItemFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Collapse indicator e status (mantém igual)...
            if item.subItems != nil && !item.subItems!.isEmpty {
                Image(systemName: item.isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: statusFontSize))
                    .foregroundColor(.secondary)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            onToggleCollapse()
                        }
                    }
            } else {
                Image(systemName: "circle.fill")
                    .font(.system(size: 4))
                    .foregroundColor(.clear)
            }
            
            // Status indicator
            Text(item.status.rawValue)
                .font(.system(size: statusFontSize, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.2))
                .cornerRadius(4)
                .scaleEffect(statusScale)
            
            // Task counter
            if item.status == .proj || item.status == .subProj {
                let counts = item.taskCounts
                TaskCounterView(
                    completed: counts.completed,
                    total: counts.total,
                    fontSize: statusFontSize
                )
            }
            
            // Title area
            if isEditing {
                if viewModel.isShowingDeleteConfirmation {
                    ZStack {
                        HStack(spacing: 12) {
                            
                            Text("Delete this item?")
                                .foregroundColor(.secondary)
                            
                            Text("YES")
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(viewModel.deleteConfirmationOption == .yes ? Color.red : Color.gray.opacity(0.2))
                                .foregroundColor(viewModel.deleteConfirmationOption == .yes ? .white : .primary)
                                .cornerRadius(4)
                            
                            Text("NO")
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(viewModel.deleteConfirmationOption == .no ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(viewModel.deleteConfirmationOption == .no ? .white : .primary)
                                .cornerRadius(4)
                            
                        }
                        .font(.system(size: fontSize))
                        
                        DeleteConfirmationNSView(
                            viewModel: viewModel,
                            fontSize: fontSize,
                            isNewItemFieldFocused: _isNewItemFieldFocused
                        )
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                    }
                } else {
                    CustomTextField(
                        text: $editingTitle,
                        onSubmit: { onTitleChange(editingTitle) },
                        cursorPosition: editingDirection,
                        fontSize: fontSize,
                        onEmptyDelete: {
                            if editingTitle.isEmpty {
                                viewModel.isShowingDeleteConfirmation = true
                            }
                        }
                    )
                    .onAppear { editingTitle = item.title }
                }
            } else {
                Text(item.title)
                    .font(.system(size: fontSize))
            }
        }
        .padding(.leading, CGFloat(level) * 20)
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var statusColor: Color {
        switch item.status {
        case .todo: return .blue
        case .doing: return .orange
        case .done: return .green
        case .proj, .subProj: return .purple
        case .someday, .maybe, .future: return .gray
        }
    }
}

struct DeleteConfirmationNSView: NSViewRepresentable {
    @ObservedObject var viewModel: TaskListViewModel
    let fontSize: Double
    @FocusState var isNewItemFieldFocused: Bool
    
    class Coordinator: NSResponder {
        var parent: DeleteConfirmationNSView
        
        init(_ parent: DeleteConfirmationNSView) {
            self.parent = parent
            super.init()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 123, 124: // Left arrow (123) or right arrow (124)
                parent.viewModel.deleteConfirmationOption.toggle()
            case 36: // Return
                let wasYes = parent.viewModel.deleteConfirmationOption == .yes
                parent.viewModel.handleDeleteConfirmation(confirmed: wasYes)
                DispatchQueue.main.async {
                    self.parent.isNewItemFieldFocused = true
                }
            case 53: // Escape
                parent.viewModel.isShowingDeleteConfirmation = false
                parent.viewModel.editingItemId = nil
                DispatchQueue.main.async {
                    self.parent.isNewItemFieldFocused = true
                }
            default:
                break
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.nextResponder = context.coordinator
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(context.coordinator)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(context.coordinator)
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

// Shake effect modifier
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var shake: Bool
    
    var animatableData: CGFloat {
        get { CGFloat(shake ? 1 : 0) }
        set { }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        guard shake else { return ProjectionTransform(.identity) }
        
        let animation = Float(animatableData)
        let curve = sin(Float(shakesPerUnit) * 2.0 * .pi * animation)
        let offsetX = CGFloat(curve) * amount
        
        return ProjectionTransform(CGAffineTransform(translationX: offsetX, y: 0))
    }
}

extension Array {
    var nilIfEmpty: Self? {
        isEmpty ? nil : self
    }
}

extension Item {
    /// Returns the count of completed and total direct tasks
    var taskCounts: (completed: Int, total: Int) {
        guard let subItems = subItems else { return (0, 0) }
        
        let total = subItems.count
        let completed = subItems.filter { item in
            switch item.status {
            case .done:
                return true
            case .proj, .subProj:
                // For projects and subprojects, only count as done if all their tasks are done
                let (completedSub, totalSub) = item.taskCounts
                return completedSub == totalSub && totalSub > 0
            default:
                return false
            }
        }.count
        
        return (completed, total)
    }
}

// Preview provider for SwiftUI canvas
struct TaskListView_Previews: PreviewProvider {
    static var previews: some View {
        TaskListView()
    }
}


