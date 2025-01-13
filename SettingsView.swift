import SwiftUI
import AppKit

struct KeyboardNavigationView: NSViewRepresentable {
    let onKeyPress: (NSEvent) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyboardView()
        view.onKeyPress = onKeyPress
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? KeyboardView {
            view.onKeyPress = onKeyPress
        }
    }
    
    class KeyboardView: NSView {
        var onKeyPress: ((NSEvent) -> Void)?
        
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.acceptsTouchEvents = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override var acceptsFirstResponder: Bool { true }
        
        override func keyDown(with event: NSEvent) {
            onKeyPress?(event)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss
    @State private var selectedColorIndex = 0
    @State private var isAddingColor = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    @State private var selectedBackgroundColor: Color
    @State private var selectedTextColor: Color
    @State private var selectedInputBarBackgroundColor: Color
    @State private var selectedInputBarTextColor: Color
    @State private var selectedInputBarBorderColor: Color
    @State private var inputBarBorderWidth: Double
    @State private var inputBarCornerRadius: Double
    @State private var inputBarShowBorder: Bool
    
    init(settings: AppSettings) {
        self.settings = settings
        _selectedBackgroundColor = State(initialValue: settings.backgroundColor)
        _selectedTextColor = State(initialValue: settings.textColor)
        _selectedInputBarBackgroundColor = State(initialValue: settings.inputBarBackgroundColor)
        _selectedInputBarTextColor = State(initialValue: settings.inputBarTextColor)
        _selectedInputBarBorderColor = State(initialValue: settings.inputBarBorderColor)
        _inputBarBorderWidth = State(initialValue: settings.inputBarBorderWidth)
        _inputBarCornerRadius = State(initialValue: settings.inputBarCornerRadius)
        _inputBarShowBorder = State(initialValue: settings.inputBarShowBorder)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Color Settings")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Accent Color Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Accent Color")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("Add Color") {
                                isAddingColor = true
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                        }
                        
                        // Color Grid
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 12)
                        ], spacing: 12) {
                            ForEach(Array(settings.availableColors.enumerated()), id: \.element.name) { index, colorOption in
                                ColorOptionView(
                                    name: colorOption.name,
                                    color: colorOption.color,
                                    isSelected: settings.selectedColorName == colorOption.name,
                                    hasFocus: selectedColorIndex == index,
                                    isSystem: index < AppSettings.systemColors.count,
                                    onDelete: {
                                        if let customColor = settings.customColors.first(where: { $0.name == colorOption.name }) {
                                            settings.removeCustomColor(id: customColor.id)
                                        }
                                    }
                                )
                                .onTapGesture {
                                    selectedColorIndex = index
                                    settings.updateAccentColor(colorOption.name)
                                }
                            }
                        }
                        
                        // Opacity Control
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Selection Opacity")
                                .font(.headline)
                            
                            HStack {
                                Slider(value: $settings.accentOpacity, in: 0.1...1.0)
                                Text(String(format: "%.1f", settings.accentOpacity))
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                                    .frame(width: 40)
                            }
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(settings.accentColor.opacity(settings.accentOpacity))
                                .frame(height: 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding(.top, 8)
                    }
                    
                    Divider()
                    
                    // App Colors Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("App Colors")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            ColorPickerRow(label: "Background", selection: $selectedBackgroundColor) { newColor in
                                settings.updateBackgroundColor(newColor)
                            }
                            
                            ColorPickerRow(label: "Text", selection: $selectedTextColor) { newColor in
                                settings.updateTextColor(newColor)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Input Bar Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Input Bar")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            ColorPickerRow(label: "Background", selection: $selectedInputBarBackgroundColor) { newColor in
                                settings.updateInputBarBackgroundColor(newColor)
                            }
                            
                            ColorPickerRow(label: "Text", selection: $selectedInputBarTextColor) { newColor in
                                settings.updateInputBarTextColor(newColor)
                            }
                            
                            Toggle("Show Border", isOn: $inputBarShowBorder)
                                .onChange(of: inputBarShowBorder) { newValue in
                                    settings.updateInputBarShowBorder(newValue)
                                }
                            
                            if inputBarShowBorder {
                                ColorPickerRow(label: "Border", selection: $selectedInputBarBorderColor) { newColor in
                                    settings.updateInputBarBorderColor(newColor)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Border Width")
                                    HStack {
                                        Slider(value: $inputBarBorderWidth, in: 0.5...5.0, step: 0.5)
                                            .frame(width: 200)
                                        Text(String(format: "%.1f", inputBarBorderWidth))
                                            .monospacedDigit()
                                            .foregroundColor(.secondary)
                                            .frame(width: 40)
                                    }
                                }
                                .onChange(of: inputBarBorderWidth) { newValue in
                                    settings.updateInputBarBorderWidth(newValue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Corner Radius")
                                    HStack {
                                        Slider(value: $inputBarCornerRadius, in: 0...20.0, step: 1.0)
                                            .frame(width: 200)
                                        Text(String(format: "%.0f", inputBarCornerRadius))
                                            .monospacedDigit()
                                            .foregroundColor(.secondary)
                                            .frame(width: 40)
                                    }
                                }
                                .onChange(of: inputBarCornerRadius) { newValue in
                                    settings.updateInputBarCornerRadius(newValue)
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 600, height: 700)
        .sheet(isPresented: $isAddingColor) {
            AddCustomColorView(
                isPresented: $isAddingColor,
                settings: settings,
                showError: { message in
                    errorMessage = message
                    showingError = true
                }
            )
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .background(
            KeyboardNavigationView { event in
                handleKeyboardNavigation(event)
            }
        )
        .onAppear {
            selectedColorIndex = settings.availableColors.firstIndex(where: { $0.name == settings.selectedColorName }) ?? 0
        }
    }
    
    private func handleKeyboardNavigation(_ event: NSEvent) {
        switch event.keyCode {
        case 123: // Left arrow
            if selectedColorIndex > 0 {
                selectedColorIndex -= 1
                updateSelectedColor()
            }
        case 124: // Right arrow
            if selectedColorIndex < settings.availableColors.count - 1 {
                selectedColorIndex += 1
                updateSelectedColor()
            }
        case 125: // Down arrow
            let colorsPerRow = 4
            let currentRow = selectedColorIndex / colorsPerRow
            let currentCol = selectedColorIndex % colorsPerRow
            let totalRows = (settings.availableColors.count + colorsPerRow - 1) / colorsPerRow
            
            if currentRow < totalRows - 1 {
                let targetIndex = (currentRow + 1) * colorsPerRow + currentCol
                if targetIndex < settings.availableColors.count {
                    selectedColorIndex = targetIndex
                    updateSelectedColor()
                }
            }
        case 126: // Up arrow
            let colorsPerRow = 4
            let currentRow = selectedColorIndex / colorsPerRow
            let currentCol = selectedColorIndex % colorsPerRow
            
            if currentRow > 0 {
                selectedColorIndex = (currentRow - 1) * colorsPerRow + currentCol
                updateSelectedColor()
            }
        default:
            break
        }
    }
    
    private func updateSelectedColor() {
        let colorOption = settings.availableColors[selectedColorIndex]
        settings.updateAccentColor(colorOption.name)
    }
}

struct ColorPickerRow: View {
    let label: String
    @Binding var selection: Color
    let onChange: (Color) -> Void
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 100, alignment: .leading)
            Spacer()
            ColorPicker("", selection: $selection)
                .onChange(of: selection, perform: onChange)
        }
    }
}

struct ColorOptionView: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let hasFocus: Bool
    let isSystem: Bool
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        VStack {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 32, height: 32)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                if !isSystem {
                    Button(action: { onDelete?() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                            .background(Color.white.clipShape(Circle()))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 8, y: -8)
                }
            }
            
            Text(name)
                .font(.system(size: 12))
        }
        .frame(height: 60)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(hasFocus ? color : (isSelected ? color : Color.clear), lineWidth: 2)
        )
    }
}

struct AddCustomColorView: View {
    @Binding var isPresented: Bool
    @ObservedObject var settings: AppSettings
    let showError: (String) -> Void
    
    @State private var name = ""
    @State private var hex = "#000000"
    @State private var selectedColor = Color.black
    @State private var isEditingHex = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Custom Color")
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Color Name")
                    .font(.headline)
                TextField("e.g. Deep Purple", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("HEX Code")
                    .font(.headline)
                TextField("#000000", text: $hex)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: hex) { newValue in
                        if !isEditingHex {
                            if let color = Color(hex: newValue) {
                                selectedColor = color
                            }
                        }
                        isEditingHex = false
                    }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Color Picker")
                    .font(.headline)
                ColorPicker("Select Color", selection: $selectedColor)
                    .labelsHidden()
                    .onChange(of: selectedColor) { newColor in
                        if let hexString = newColor.toHex() {
                            isEditingHex = true
                            hex = hexString
                        }
                    }
                
                // Preview da cor selecionada
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedColor)
                    .frame(height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    isPresented = false
                }
                
                Button("Add") {
                    if name.isEmpty {
                        showError("Please enter a color name")
                        return
                    }
                    
                    if !settings.addCustomColor(name: name, hex: hex) {
                        showError("Invalid color code or name already exists")
                        return
                    }
                    
                    isPresented = false
                }
                .keyboardShortcut(.return)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 300)
    }
}
