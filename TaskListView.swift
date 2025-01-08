import SwiftUI

/// View model to manage the task list state
class TaskListViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var editingItemId: UUID?
    @Published var newItemText: String = ""
    @Published var selectedItemId: UUID?
    @Published var editingDirection: EditDirection = .right
    @Published var shakeSelected: Bool = false
    
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
                    let child = parent.subItems!.remove(at: childIndex)
                    
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
    
    // Helper function to create flattened list in ViewModel
    private func buildFlattenedList(items: [Item]) -> [FlattenedItem] {
        var result: [FlattenedItem] = []
        
        for item in items {
            result.append(FlattenedItem(item: item, level: 0))
            if let subItems = item.subItems {
                result.append(contentsOf: buildFlattenedSubItems(items: subItems, level: 1))
            }
        }
        
        return result
    }

    private func buildFlattenedSubItems(items: [Item], level: Int) -> [FlattenedItem] {
        var result: [FlattenedItem] = []
        
        for item in items {
            result.append(FlattenedItem(item: item, level: level))
            if let subItems = item.subItems {
                result.append(contentsOf: buildFlattenedSubItems(items: subItems, level: level + 1))
            }
        }
        
        return result
    }

    private struct FlattenedItem {
        let item: Item
        let level: Int
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
    
    private struct FlattenedItem: Identifiable {
        let id = UUID()
        let item: Item
        let level: Int
    }
    
    /// Converte a estrutura hierárquica em uma lista plana para exibição
    private func buildFlattenedList(items: [Item], level: Int = 0) -> [FlattenedItem] {
        var result: [FlattenedItem] = []
        
        for item in items {
            result.append(FlattenedItem(item: item, level: level))
            if let subItems = item.subItems {
                result.append(contentsOf: buildFlattenedList(items: subItems, level: level + 1))
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(buildFlattenedList(items: viewModel.items), id: \.id) { itemInfo in
                ItemRowView(
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
                    level: itemInfo.level  // Novo parâmetro
                )
                .background(viewModel.selectedItemId == itemInfo.item.id ? Color.accentColor.opacity(0.5) : Color.clear)
                .modifier(ShakeEffect(shake: itemInfo.item.id == viewModel.selectedItemId && viewModel.shakeSelected))
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
                
                // Zoom out shortcut
                Button("") {
                    zoomLevel = max(minZoom, zoomLevel - zoomStep)
                }
                .keyboardShortcut(KeyboardShortcut("-", modifiers: .command))
                .opacity(0)
                .frame(maxWidth: 0, maxHeight: 0)
                    
                // Move hierarchy with Command+Option
                Button("") { viewModel.moveSelectedHierarchyUp() }
                    .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                    .opacity(0)
                    .frame(maxWidth: 0, maxHeight: 0)

                Button("") { viewModel.moveSelectedHierarchyDown() }
                    .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                    .opacity(0)
                    .frame(maxWidth: 0, maxHeight: 0)

            }
            
            // New item field
            if viewModel.editingItemId == nil {
                TextField("New item...", text: $viewModel.newItemText)
                    .textFieldStyle(.plain)
                    .font(.system(size: baseNewItemSize * zoomLevel)) // Adiciona o zoom da fonte aqui
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .focused($isNewItemFieldFocused)
                    .onSubmit {
                        viewModel.commitNewItem()
                        // Mantém o foco no campo após adicionar
                        isNewItemFieldFocused = true
                    }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.textBackgroundColor))
        .onKeyPress(.upArrow) {
            viewModel.selectPreviousItem()
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.selectNextItem()
            return .handled
        }
        .onKeyPress(.space) { // Handle space key to start new item
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

// Custom NSTextField wrapper that gives us more control
struct CustomTextField: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    let cursorPosition: TaskListViewModel.EditDirection
    let fontSize: Double
    
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
                // Primeiro removemos o foco
                control.window?.makeFirstResponder(nil)
                // Depois chamamos o onSubmit
                DispatchQueue.main.async {
                    self.parent.onSubmit()
                }
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

// Updated ItemRowView using the custom text field
struct ItemRowView: View {
    let item: Item
    let isSelected: Bool
    let isEditing: Bool
    let editingDirection: TaskListViewModel.EditDirection
    let onTitleChange: (String) -> Void
    let fontSize: Double
    let statusFontSize: Double
    let level: Int  // Novo parâmetro
    
    @State private var editingTitle: String = ""
    @State private var statusScale: Double = 1.0
    
    var body: some View {
        HStack(spacing: 8) {
            // Status indicator com tamanho de fonte ajustável
            Text(item.status.rawValue)
                .font(.system(size: statusFontSize, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.2))
                .cornerRadius(4)
                .scaleEffect(statusScale)

            // Debug: Mostra o nível
            Text("L\(level)")
                .font(.system(size: statusFontSize * 0.8, design: .monospaced))
                .foregroundColor(.gray)
            
            // Title com tamanho de fonte ajustável
            if isEditing {
                CustomTextField(
                    text: $editingTitle,
                    onSubmit: { onTitleChange(editingTitle) },
                    cursorPosition: editingDirection,
                    fontSize: fontSize
                )
                .onAppear { editingTitle = item.title }
                .padding(.leading, CGFloat(level) * 20)
            } else {
                Text(item.title)
                    .font(.system(size: fontSize))
            }
        }
        .padding(.leading, CGFloat(level) * 20)
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: item.nestingLevel)
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

extension TaskListViewModel {
    /// Estrutura auxiliar para operações de hierarquia
    private struct ItemPath {
        let parentIndex: Int?
        let index: Int
        let level: Int
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

// Preview provider for SwiftUI canvas
struct TaskListView_Previews: PreviewProvider {
    static var previews: some View {
        TaskListView()
    }
}
