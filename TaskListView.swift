import SwiftUI

/// View model to manage the task list state
class TaskListViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var editingItemId: UUID?
    @Published var newItemText: String = ""
    @Published var selectedItemId: UUID?
    @Published var editingDirection: EditDirection = .right
    
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
}

/// Main view for the task list
struct TaskListView: View {
    @StateObject private var viewModel = TaskListViewModel()
    @FocusState private var isNewItemFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.items) { item in
                ItemRowView(
                    item: item,
                    isSelected: viewModel.selectedItemId == item.id,
                    isEditing: viewModel.editingItemId == item.id,
                    editingDirection: viewModel.editingDirection,
                    onTitleChange: { newTitle in
                        viewModel.updateItemTitle(item.id, newTitle: newTitle)
                        isNewItemFieldFocused = true
                    }
                )
                .background(viewModel.selectedItemId == item.id ? Color.accentColor.opacity(0.1) : Color.clear)
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
            }
            
            // New item field
            if viewModel.editingItemId == nil {
                TextField("New item...", text: $viewModel.newItemText)
                    .textFieldStyle(.plain)
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
    }
}

// Custom NSTextField wrapper that gives us more control
struct CustomTextField: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    let cursorPosition: TaskListViewModel.EditDirection
    
    // Add state to track if we've positioned the cursor
    @State private var hasPositionedCursor = false
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CustomTextField
        
        init(_ parent: CustomTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                // Remove o foco do campo após submeter
                control.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        textField.drawsBackground = false
        textField.isBezeled = false
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        
        // Only position cursor if we haven't done it yet
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
                // Mark that we've positioned the cursor
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
    var onTitleChange: (String) -> Void
    
    @State private var editingTitle: String = ""
    @State private var statusScale: Double = 1.0
    
    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Text(item.status.rawValue)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.2))
                .cornerRadius(4)
                .scaleEffect(statusScale)
            
            // Title with editing mode
            if isEditing {
                CustomTextField(
                    text: $editingTitle,
                    onSubmit: { onTitleChange(editingTitle) },
                    cursorPosition: editingDirection
                )
                .onAppear { editingTitle = item.title }
                .padding(.leading, CGFloat(item.nestingLevel) * 20)
            } else {
                Text(item.title)
                    .padding(.leading, CGFloat(item.nestingLevel) * 20)
            }
        }
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

// Preview provider for SwiftUI canvas
struct TaskListView_Previews: PreviewProvider {
    static var previews: some View {
        TaskListView()
    }
}
