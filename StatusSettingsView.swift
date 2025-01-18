import SwiftUI

struct StatusSettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedStyleIndex = 0
    @State private var draggedStatus: CustomStatus?
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
    
    var body: some View {
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
}

struct AddCustomStatusView: View {
    @Binding var isPresented: Bool
    @ObservedObject var settings: AppSettings
    let category: StatusCategory
    let showError: (String) -> Void
    
    @State private var name = ""
    @State private var rawValue = ""
    @State private var selectedColor = Color.blue
    @State private var selectedBgColor = Color.black
    @State private var selectedTextColor = Color.white
    @State private var hex = "#0000FF"
    @State private var bgHex = "#000000"
    @State private var textHex = "#FFFFFF"
    @State private var isEditingHex = false
    @State private var showCounter = false
    @State private var forceCustomColors = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add \(category.rawValue) Status")
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Name")
                    .font(.headline)
                TextField("e.g. In Progress", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Status Code")
                    .font(.headline)
                TextField("e.g. INPROG", text: $rawValue)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: rawValue) { newValue in
                        rawValue = newValue.uppercased()
                    }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Colors")
                    .font(.headline)
                
                // Main Color Picker
                HStack {
                    Text("Main Color:")
                    ColorPicker("", selection: $selectedColor)
                        .labelsHidden()
                        .onChange(of: selectedColor) { newColor in
                            if let hexString = newColor.toHex() {
                                isEditingHex = true
                                hex = hexString
                            }
                        }
                    TextField("", text: $hex)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                
                // Background Color Picker
                HStack {
                    Text("Background:")
                    ColorPicker("", selection: $selectedBgColor)
                        .labelsHidden()
                        .onChange(of: selectedBgColor) { newColor in
                            if let hexString = newColor.toHex() {
                                bgHex = hexString
                            }
                        }
                    TextField("", text: $bgHex)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                
                // Text Color Picker
                HStack {
                    Text("Text Color:")
                    ColorPicker("", selection: $selectedTextColor)
                        .labelsHidden()
                        .onChange(of: selectedTextColor) { newColor in
                            if let hexString = newColor.toHex() {
                                textHex = hexString
                            }
                        }
                    TextField("", text: $textHex)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Style Options")
                        .font(.headline)
                    
                    Toggle("Force Custom Colors", isOn: $forceCustomColors)
                        .help("Always use custom colors for this status, ignoring global style")
                    
                    if category != .task {
                        Toggle("Show Task Counter", isOn: $showCounter)
                    }
                }
                
                // Preview
                Text("Preview:")
                    .font(.headline)
                    .padding(.top, 8)
                
                HStack {
                    ForEach(StatusStyle.allCases, id: \.self) { style in
                        let previewStatus = CustomStatus(
                            id: UUID(),
                            name: name,
                            rawValue: rawValue.isEmpty ? "STATUS" : rawValue,
                            colorHex: hex,
                            category: category,
                            order: 0,
                            isDefault: false,
                            showCounter: showCounter,
                            backgroundColor: bgHex,
                            textColor: textHex,
                            forceCustomColors: false
                        )
                        
                        let previewItemStatus = ItemStatus.custom(
                            rawValue.isEmpty ? "STATUS" : rawValue,
                            colorHex: hex,
                            customStatus: previewStatus
                        )
                        
                        style.apply(
                            to: Text(rawValue.isEmpty ? "STATUS" : rawValue),
                            color: selectedColor,
                            status: previewItemStatus,
                            fontSize: 11
                        )
                    }
                }
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    isPresented = false
                }
                
                Button("Add") {
                    guard !name.isEmpty else {
                        showError("Please enter a status name")
                        return
                    }
                    
                    guard !rawValue.isEmpty else {
                        showError("Please enter a status code")
                        return
                    }
                    
                    if !settings.addCustomStatus(
                        name: name,
                        rawValue: rawValue,
                        colorHex: hex,
                        category: category,
                        showCounter: showCounter,
                        backgroundColor: bgHex,
                        textColor: textHex,
                        forceCustomColors: forceCustomColors  // Nova propriedade
                    ) {
                        showError("Status name or code already exists")
                        return
                    }
                    
                    isPresented = false
                }
                .keyboardShortcut(.return)
            }
            .padding()
            .frame(width: 400)
        }
    }
}

struct EditCustomStatusView: View {
    @Binding var isPresented: Bool
    @ObservedObject var settings: AppSettings
    let status: CustomStatus
    
    @State private var name: String
    @State private var rawValue: String
    @State private var selectedColor: Color
    @State private var selectedBgColor: Color
    @State private var selectedTextColor: Color
    @State private var hex: String
    @State private var bgHex: String
    @State private var textHex: String
    @State private var isEditingHex = false
    @State private var showCounter: Bool
    @State private var forceCustomColors: Bool
    
    init(isPresented: Binding<Bool>, settings: AppSettings, status: CustomStatus) {
        self._isPresented = isPresented
        self.settings = settings
        self.status = status
        
        // Initialize state with current status values
        _name = State(initialValue: status.name)
        _rawValue = State(initialValue: status.rawValue)
        _selectedColor = State(initialValue: status.color)
        _selectedBgColor = State(initialValue: status.bgColor)
        _selectedTextColor = State(initialValue: status.txtColor)
        _hex = State(initialValue: status.colorHex)
        _bgHex = State(initialValue: status.backgroundColor)
        _textHex = State(initialValue: status.textColor)
        _showCounter = State(initialValue: status.showCounter)
        _forceCustomColors = State(initialValue: status.forceCustomColors)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("Edit \(status.category.rawValue) Status")
                .font(.title2)
                .padding(.bottom, 8)
            
            // Form content in a scrollview
            ScrollView {
                VStack(spacing: 24) {
                    // Basic Information Section
                    GroupBox("Basic Information") {
                        VStack(alignment: .leading, spacing: 16) {
                            // Display Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Display Name")
                                    .font(.headline)
                                TextField("e.g. In Progress", text: $name)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            // Status Code
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Status Code")
                                    .font(.headline)
                                TextField("e.g. IN_PROGRESS", text: $rawValue)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: rawValue) { newValue in
                                        rawValue = newValue.uppercased()
                                    }
                            }
                        }
                        .padding()
                    }
                    
                    // Colors Section
                    GroupBox("Colors") {
                        VStack(alignment: .leading, spacing: 16) {
                            // Main Color
                            ColorPickerWithHex(
                                title: "Status Color",
                                color: $selectedColor,
                                hex: $hex
                            )
                            
                            // Background Color
                            ColorPickerWithHex(
                                title: "Background Color",
                                color: $selectedBgColor,
                                hex: $bgHex
                            )
                            
                            // Text Color
                            ColorPickerWithHex(
                                title: "Text Color",
                                color: $selectedTextColor,
                                hex: $textHex
                            )
                        }
                        .padding()
                    }
                    
                    // Style Options Section
                    GroupBox("Style Options") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Force Custom Colors", isOn: $forceCustomColors)
                                .help("Always use custom colors for this status, ignoring global style")
                            
                            if status.category != .task {
                                Toggle("Show Task Counter", isOn: $showCounter)
                            }
                        }
                        .padding()
                    }
                    
                    // Preview Section
                    GroupBox("Preview") {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Style Previews")
                                .font(.headline)
                            
                            HStack(spacing: 12) {
                                ForEach(StatusStyle.allCases, id: \.self) { style in
                                    VStack(spacing: 8) {
                                        let previewStatus = CustomStatus(
                                            id: status.id,
                                            name: name,
                                            rawValue: rawValue.isEmpty ? "STATUS" : rawValue,
                                            colorHex: hex,
                                            category: status.category,
                                            order: status.order,
                                            isDefault: status.isDefault,
                                            showCounter: showCounter,
                                            backgroundColor: bgHex,
                                            textColor: textHex,
                                            forceCustomColors: forceCustomColors
                                        )
                                        
                                        let previewItemStatus = ItemStatus.custom(
                                            rawValue.isEmpty ? "STATUS" : rawValue,
                                            colorHex: hex,
                                            customStatus: previewStatus
                                        )
                                        
                                        style.apply(
                                            to: Text(rawValue.isEmpty ? "STATUS" : rawValue),
                                            color: selectedColor,
                                            status: previewItemStatus,
                                            fontSize: 11
                                        )
                                        
                                        Text(style.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                .padding()
            }
            
            // Action Buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    isPresented = false
                }
                
                Button("Save") {
                    settings.updateCustomStatus(
                        id: status.id,
                        name: name,
                        rawValue: rawValue,
                        colorHex: hex,
                        showCounter: showCounter,
                        backgroundColor: bgHex,
                        textColor: textHex,
                        forceCustomColors: forceCustomColors
                    )
                    isPresented = false
                }
                .keyboardShortcut(.return)
            }
            .padding(.vertical)
        }
        .frame(width: 600, height: 700)
    }
}

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
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: 40, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
}
