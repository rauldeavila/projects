import SwiftUI

// Additional supporting views
struct StatusStylePreview: View {
    let style: StatusStyle
    let isSelected: Bool
    let hasFocus: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            let sampleStatus = ItemStatus.custom("SAMPLE", colorHex: "#007AFF")
            
            style.apply(
                to: Text("SAMPLE"),
                color: .blue,
                status: sampleStatus,
                fontSize: 11
            )
            
            Text(style.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 120)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(hasFocus ? Color.accentColor : (isSelected ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.2)), lineWidth: 1)
                )
        )
    }
}

struct StatusCategoryColumn: View {
    let category: StatusCategory
    let statuses: [CustomStatus]
    let settings: AppSettings
    let style: StatusStyle
    let onError: (String) -> Void
    
    @State private var isAddingStatus = false
    @State private var draggedStatus: CustomStatus?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text(category.rawValue)
                .font(.headline)
                .fontWeight(.medium)
            
            // Status List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(statuses) { status in
                        StatusItemView(
                            status: status,
                            style: style,
                            settings: settings,
                            onDelete: {
                                settings.removeCustomStatus(id: status.id)
                            }
                        )
                        .onDrag {
                            self.draggedStatus = status
                            return NSItemProvider(object: status.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: DropViewDelegate(
                            item: status,
                            draggedItem: $draggedStatus,
                            items: statuses,
                            category: category,
                            settings: settings
                        ))
                    }
                    
                    // Add Status Button
                    Button(action: { isAddingStatus = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Status")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(12)
            }
            .frame(height: 300)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .sheet(isPresented: $isAddingStatus) {
            AddCustomStatusView(
                isPresented: $isAddingStatus,
                settings: settings,
                category: category,
                showError: onError
            )
        }
    }
}

struct DropViewDelegate: DropDelegate {
    let item: CustomStatus
    @Binding var draggedItem: CustomStatus?
    let items: [CustomStatus]
    let category: StatusCategory
    let settings: AppSettings
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedItem = self.draggedItem else { return false }
        guard draggedItem.category == category else { return false }
        
        let fromIndex = items.firstIndex(where: { $0.id == draggedItem.id }) ?? 0
        let toIndex = items.firstIndex(where: { $0.id == item.id }) ?? 0
        
        withAnimation {
            settings.updateOrder(in: category, oldIndex: fromIndex, newIndex: toIndex)
        }
        
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

struct StatusItemView: View {
    let status: CustomStatus
    let style: StatusStyle
    let settings: AppSettings
    var onDelete: (() -> Void)? = nil
    var isDragging: Bool = false
    @State private var isEditing = false
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            let itemStatus = ItemStatus.custom(status.rawValue, colorHex: status.colorHex, customStatus: status)
            
            style.apply(
                to: Text(status.rawValue),
                color: status.color,
                status: itemStatus,
                fontSize: 12
            )
            
            Spacer()
            
            // Show counter indicator for non-task status if enabled
            if status.category != .task {
                Image(systemName: status.showCounter ? "number.square.fill" : "number.square")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
            }
            
            Text(status.name)
                .foregroundStyle(.secondary)
                .font(.caption)
            
            if !status.isDefault, let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red.opacity(isHovered ? 1 : 0.8))
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            if !status.isDefault {
                isEditing = true
            }
        }
        .sheet(isPresented: $isEditing) {
            EditCustomStatusView(
                isPresented: $isEditing,
                settings: settings,
                status: status
            )
        }
    }
}// Form data model to manage status editor state
struct StatusFormData {
    var name: String
    var rawValue: String
    var selectedColor: Color
    var selectedBgColor: Color
    var selectedTextColor: Color
    var hex: String
    var bgHex: String
    var textHex: String
    var showCounter: Bool
    var forceCustomColors: Bool
    
    static func empty() -> StatusFormData {
        StatusFormData(
            name: "",
            rawValue: "",
            selectedColor: .blue,
            selectedBgColor: .black,
            selectedTextColor: .white,
            hex: "#0000FF",
            bgHex: "#000000",
            textHex: "#FFFFFF",
            showCounter: false,
            forceCustomColors: false
        )
    }
    
    static func fromStatus(_ status: CustomStatus) -> StatusFormData {
        StatusFormData(
            name: status.name,
            rawValue: status.rawValue,
            selectedColor: status.color,
            selectedBgColor: status.bgColor,
            selectedTextColor: status.txtColor,
            hex: status.colorHex,
            bgHex: status.backgroundColor,
            textHex: status.textColor,
            showCounter: status.showCounter,
            forceCustomColors: status.forceCustomColors
        )
    }
}

struct StatusEditorView: View {
    @Binding var isPresented: Bool
    @ObservedObject var settings: AppSettings
    let category: StatusCategory
    let mode: EditorMode
    let showError: (String) -> Void
    
    enum EditorMode: Equatable {
        case create
        case edit(CustomStatus)
        
        static func == (lhs: EditorMode, rhs: EditorMode) -> Bool {
            switch (lhs, rhs) {
            case (.create, .create):
                return true
            case (.edit(let lhsStatus), .edit(let rhsStatus)):
                return lhsStatus.id == rhsStatus.id
            default:
                return false
            }
        }
    }
    
    @State private var formData: StatusFormData
    
    init(isPresented: Binding<Bool>, settings: AppSettings, category: StatusCategory, mode: EditorMode, showError: @escaping (String) -> Void) {
        self._isPresented = isPresented
        self.settings = settings
        self.category = category
        self.mode = mode
        self.showError = showError
        
        // Initialize form data based on mode
        switch mode {
        case .create:
            _formData = State(initialValue: .empty())
        case .edit(let status):
            _formData = State(initialValue: .fromStatus(status))
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text(mode == .create ? "Add \(category.rawValue) Status" : "Edit \(category.rawValue) Status")
                .font(.title2)
                .padding(.bottom, 8)
                .padding(.top, 20)
            
            // Form content in a scrollview
            ScrollView {
                VStack(spacing: 24) {

                    HStack {
                        
                        VStack {
                            
                            GroupBox("Basic Information") {
                                
                                VStack(alignment: .leading, spacing: 16) {
                                    // Display Name
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Display Name")
                                            .font(.headline)
                                        TextField("e.g. In Progress", text: $formData.name)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    
                                    // Status Code
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Status Code")
                                            .font(.headline)
                                        TextField("e.g. IN_PROGRESS", text: $formData.rawValue)
                                            .textFieldStyle(.roundedBorder)
                                            .onChange(of: formData.rawValue) { newValue in
                                                formData.rawValue = newValue.uppercased()
                                            }
                                    }
                                    
                                    HStack(spacing: 20) {
                                        Toggle("Force Custom Colors", isOn: $formData.forceCustomColors)
                                            .help("Always use custom colors for this status, ignoring global style")
                                        
                                        if category != .task {
                                            Toggle("Show Task Counter", isOn: $formData.showCounter)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                                .padding()
                            }
                            
                            Spacer()


                        }
                        
                        VStack {
                            GroupBox("Colors") {
                                VStack(alignment: .leading, spacing: 16) {
                                    // Main Color
                                    ColorPickerWithHex(
                                        title: "Status Color",
                                        color: $formData.selectedColor,
                                        hex: $formData.hex
                                    )
                                    
                                    // Background Color
                                    ColorPickerWithHex(
                                        title: "Background Color",
                                        color: $formData.selectedBgColor,
                                        hex: $formData.bgHex
                                    )
                                    
                                    // Text Color
                                    ColorPickerWithHex(
                                        title: "Text Color",
                                        color: $formData.selectedTextColor,
                                        hex: $formData.textHex
                                    )
                                }
                                .padding()
                            }
                            
                            Spacer()
                        }
                        
                    }
                    .padding()
                    
                    VStack {
                        GroupBox("Preview") {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Style Previews")
                                    .font(.headline)
                                
                                HStack(spacing: 36) {
                                    ForEach(StatusStyle.allCases, id: \.self) { style in
                                        VStack(spacing: 8) {
                                            let previewStatus = CustomStatus(
                                                id: UUID(),
                                                name: formData.name,
                                                rawValue: formData.rawValue.isEmpty ? "STATUS" : formData.rawValue,
                                                colorHex: formData.hex,
                                                category: category,
                                                order: 0,
                                                isDefault: false,
                                                showCounter: formData.showCounter,
                                                backgroundColor: formData.bgHex,
                                                textColor: formData.textHex,
                                                forceCustomColors: formData.forceCustomColors
                                            )
                                            
                                            let previewItemStatus = ItemStatus.custom(
                                                formData.rawValue.isEmpty ? "STATUS" : formData.rawValue,
                                                colorHex: formData.hex,
                                                customStatus: previewStatus
                                            )
                                            
                                            style.apply(
                                                to: Text(formData.rawValue.isEmpty ? "STATUS" : formData.rawValue),
                                                color: formData.selectedColor,
                                                status: previewItemStatus,
                                                fontSize: 11
                                            )
                                            
                                            Text(style.rawValue)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .padding()
                    }
                    .padding(.top, -70)
                }
            }
            
            // Action Buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    isPresented = false
                }
                
                Button(mode == .create ? "Add" : "Save") {
                    switch mode {
                    case .create:
                        if formData.name.isEmpty {
                            showError("Please enter a status name")
                            return
                        }
                        
                        if formData.rawValue.isEmpty {
                            showError("Please enter a status code")
                            return
                        }
                        
                        if !settings.addCustomStatus(
                            name: formData.name,
                            rawValue: formData.rawValue,
                            colorHex: formData.hex,
                            category: category,
                            showCounter: formData.showCounter,
                            backgroundColor: formData.bgHex,
                            textColor: formData.textHex,
                            forceCustomColors: formData.forceCustomColors
                        ) {
                            showError("Status name or code already exists")
                            return
                        }
                        
                    case .edit(let status):
                        settings.updateCustomStatus(
                            id: status.id,
                            name: formData.name,
                            rawValue: formData.rawValue,
                            colorHex: formData.hex,
                            showCounter: formData.showCounter,
                            backgroundColor: formData.bgHex,
                            textColor: formData.textHex,
                            forceCustomColors: formData.forceCustomColors
                        )
                    }
                    isPresented = false
                }
                .keyboardShortcut(.return)
            }
            .padding(.vertical)
        }
        .frame(width: 600, height: 550)
    }
}

// Simplified Add and Edit views that use StatusEditorView
struct AddCustomStatusView: View {
    @Binding var isPresented: Bool
    @ObservedObject var settings: AppSettings
    let category: StatusCategory
    let showError: (String) -> Void
    
    var body: some View {
        StatusEditorView(
            isPresented: $isPresented,
            settings: settings,
            category: category,
            mode: .create,
            showError: showError
        )
    }
}

struct EditCustomStatusView: View {
    @Binding var isPresented: Bool
    @ObservedObject var settings: AppSettings
    let status: CustomStatus
    
    var body: some View {
        StatusEditorView(
            isPresented: $isPresented,
            settings: settings,
            category: status.category,
            mode: .edit(status),
            showError: { message in
                print("Error editing status: \(message)")
            }
        )
    }
}

// Helper view for color selection
struct ColorPickerWithHex: View {
    let title: String
    @Binding var color: Color
    @Binding var hex: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack(spacing: 12) {
                ColorPicker("", selection: $color)
                    .labelsHidden()
                    .onChange(of: color) { newValue in
                        if let newHex = newValue.toHex() {
                            hex = newHex
                        }
                    }
                
                TextField("", text: $hex)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .onChange(of: hex) { newValue in
                        if let newColor = Color(hex: newValue) {
                            color = newColor
                        }
                    }
//                
//                RoundedRectangle(cornerRadius: 4)
//                    .fill(color)
//                    .frame(width: 40, height: 24)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 4)
//                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
//                    )
            }
        }
    }
}

// Import StatusSettingsView here for access by TaskListView
public struct StatusSettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedStyleIndex = 0
    @State private var draggedStatus: CustomStatus?
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                Text("Status Settings")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding(.bottom, 8)
            
            // Status Style Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Status Style")
                    .font(.headline)
                    .fontWeight(.medium)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(StatusStyle.allCases.enumerated()), id: \.element) { index, style in
                            StatusStylePreview(
                                style: style,
                                isSelected: settings.statusStyle == style,
                                hasFocus: selectedStyleIndex == index
                            )
                            .onTapGesture {
                                selectedStyleIndex = index
                                settings.statusStyle = style
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            
            // Status Categories Grid
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(StatusCategory.allCases, id: \.self) { category in
                    StatusCategoryColumn(
                        category: category,
                        statuses: settings.getStatus(for: category),
                        settings: settings,
                        style: settings.statusStyle,
                        onError: { message in
                            errorMessage = message
                            showingError = true
                        }
                    )
                }
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(minWidth: 800, minHeight: 600)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
}
