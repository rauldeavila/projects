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
        if let current = currentIndex {
            let nextIndex = min(current + 1, items.count - 1)
            selectedItemId = items[nextIndex].id
        } else if !items.isEmpty {
            selectedItemId = items[0].id
        }
    }
    
    func selectPreviousItem() {
        if let current = currentIndex {
            let previousIndex = max(current - 1, 0)
            selectedItemId = items[previousIndex].id
        } else if !items.isEmpty {
            selectedItemId = items[0].id
        }
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
        guard let currentIndex = currentIndex else { return }
        var item = items[currentIndex]
        
        // Choose appropriate status array based on item type
        let statuses = item.isProject || item.isSubProject ? projectStatuses : taskStatuses
        
        // Find current status index
        guard let statusIndex = statuses.firstIndex(of: item.status) else {
            // If status not found in appropriate array, default to first status
            item.status = statuses[0]
            items[currentIndex] = item
            return
        }
        
        // Calculate next status index
        let nextIndex = (statusIndex + direction + statuses.count) % statuses.count
        item.status = statuses[nextIndex]
        items[currentIndex] = item
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
        guard let currentIndex = currentIndex, currentIndex > 0 else {
            showShakeAnimation()
            return
        }
        
        var currentItem = items[currentIndex]
        var parentItem = items[currentIndex - 1]
        
        // Check if adding would exceed max nesting level
        if parentItem.nestingLevel >= Item.maxNestingLevel - 1 {
            showShakeAnimation()
            return
        }
        
        do {
            // Remove item from current position
            if parentItem.isTask {
                parentItem.status = parentItem.nestingLevel == 0 ? .proj : .subProj
                parentItem.touch() // Força atualização
            }
            
            items.remove(at: currentIndex)
            
            // Add as child of parent
            try parentItem.addSubItem(currentItem)
            
            // Update parent status if needed
            
            // Update in items array
            items[currentIndex - 1] = parentItem

            
        } catch {
            // Restore item if operation failed
            items.insert(currentItem, at: currentIndex)
            showShakeAnimation()
        }
    }

    func dedentSelectedItem() {
        guard let currentIndex = currentIndex else {
            showShakeAnimation()
            return
        }
        
        // Find parent by traversing up the hierarchy
        var parentIndex = currentIndex - 1
        while parentIndex >= 0 {
            if items[parentIndex].subItems?.contains(where: { $0.id == items[currentIndex].id }) == true {
                break
            }
            parentIndex -= 1
        }
        
        guard parentIndex >= 0 else {
            showShakeAnimation()
            return
        }
        
        // Remove from parent's children
        var parentItem = items[parentIndex]
        let currentItem = items[currentIndex]
        
        if let childIndex = parentItem.subItems?.firstIndex(where: { $0.id == currentItem.id }) {
            parentItem.subItems?.remove(at: childIndex)
            
            // Update parent status if it has no more children
            if parentItem.subItems?.isEmpty == true {
                parentItem.status = .todo
            }
            
            // Update parent in items array
            items[parentIndex] = parentItem
            
            // Insert item at new position
            items.insert(currentItem, at: parentIndex + 1)
        }
    }

    // MARK: - Visual Feedback

    private func showShakeAnimation() {
        shakeSelected = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.shakeSelected = false
        }
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
        .onKeyPress(.tab) {
            viewModel.indentSelectedItem()
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
        guard let path = findSelectedItemPath() else { return }
        
        if path.parentIndex == nil {
            // Item está no nível raiz
            guard path.index > 0 else { return }
            
            let currentItem = items[path.index]
            items.remove(at: path.index)
            items.insert(currentItem, at: path.index - 1)
            selectedItemId = currentItem.id
            
        } else {
            // Item está em um subnível
            // TODO: Implementar movimentação dentro de subníveis
        }
    }
    
    /// Move a hierarquia selecionada para baixo
    func moveSelectedHierarchyDown() {
        guard let path = findSelectedItemPath() else { return }
        
        if path.parentIndex == nil {
            // Item está no nível raiz
            guard path.index < items.count - 1 else { return }
            
            let currentItem = items[path.index]
            items.remove(at: path.index)
            items.insert(currentItem, at: path.index + 1)
            selectedItemId = currentItem.id
            
        } else {
            // Item está em um subnível
            // TODO: Implementar movimentação dentro de subníveis
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
