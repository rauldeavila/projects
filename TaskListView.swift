import SwiftUI

/// View model to manage the task list state
class TaskListViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var editingItemId: UUID?
    @Published var newItemText: String = ""
    @Published var selectedItemId: UUID?
    
    // Current focused item index
    private var currentIndex: Int? {
        if let selectedId = selectedItemId {
            return items.firstIndex { $0.id == selectedId }
        }
        return nil
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
    }
}

/// Main view for the task list
struct TaskListView: View {
    @StateObject private var viewModel = TaskListViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.items) { item in
                ItemRowView(
                    item: item,
                    isSelected: viewModel.selectedItemId == item.id,
                    isEditing: viewModel.editingItemId == item.id,
                    onTitleChange: { newTitle in
                        viewModel.updateItemTitle(item.id, newTitle: newTitle)
                    }
                )
                .background(viewModel.selectedItemId == item.id ? Color.accentColor.opacity(0.1) : Color.clear)
            }
            
            // New item field
            if viewModel.editingItemId == nil {
                TextField("New item...", text: $viewModel.newItemText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .onSubmit {
                        viewModel.commitNewItem()
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
        .onKeyPress(.tab) {
            viewModel.startEditingSelected()
            return .handled
        }
        .onKeyPress(.space) { // Handle space key to start new item
            if viewModel.editingItemId == nil && viewModel.newItemText.isEmpty {
                viewModel.startNewItem()
                return .handled
            }
            return .ignored
        }
    }
}

/// View for a single item row
struct ItemRowView: View {
    let item: Item
    let isSelected: Bool
    let isEditing: Bool
    var onTitleChange: (String) -> Void
    @State private var editingTitle: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Text(item.status.rawValue)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.2))
                .cornerRadius(4)
            
            // Title with appropriate indentation
            if isEditing {
                TextField("", text: $editingTitle)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onAppear {
                        editingTitle = item.title
                        isFocused = true
                    }
                    .onSubmit {
                        onTitleChange(editingTitle)
                    }
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
        case .todo:
            return .blue
        case .doing:
            return .orange
        case .done:
            return .green
        case .proj, .subProj:
            return .purple
        case .someday, .maybe, .future:
            return .gray
        }
    }
}

// Preview provider for SwiftUI canvas
struct TaskListView_Previews: PreviewProvider {
    static var previews: some View {
        TaskListView()
    }
}
