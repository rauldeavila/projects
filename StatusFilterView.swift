import SwiftUI


struct StatusFiltersView: View {
    
    @ObservedObject var viewModel: TaskListViewModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        if viewModel.isInSearchMode {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Logbook chip
                    StatusFilterChip(
                        status: ItemStatus.custom("📗 LOGBOOK", colorHex: "#00FF00"),
                        isSelected: viewModel.isInLogbookMode,
                        isHighlighted: viewModel.selectedChipIndex == 0,
                        settings: settings
                    ) {
                        viewModel.selectedChipIndex = 0
                        viewModel.confirmChipSelection()
                    }
                    
                    // Existing status chips (adjust index to account for logbook)
                    ForEach(Array(settings.getStatus(for: .task).enumerated()), id: \.element.rawValue) { index, customStatus in
                        let itemStatus = ItemStatus.custom(
                            customStatus.rawValue,
                            colorHex: customStatus.colorHex,
                            customStatus: customStatus
                        )
                        
                        StatusFilterChip(
                            status: itemStatus,
                            isSelected: viewModel.selectedStatusFilter?.rawValue == itemStatus.rawValue,
                            isHighlighted: viewModel.selectedChipIndex == index + 1,
                            settings: settings
                        ) {
                            viewModel.selectedChipIndex = index + 1
                            viewModel.confirmChipSelection()
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .frame(height: 44)
            .background(settings.backgroundColor)
        }
    }
}

struct StatusFilterChip: View {
    let status: ItemStatus
    let isSelected: Bool
    let isHighlighted: Bool
    let settings: AppSettings
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            settings.statusStyle.apply(
                to: Text(status.rawValue),
                color: status.color,
                status: status,
                fontSize: 12
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? settings.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHighlighted ? settings.accentColor : (isSelected ? settings.accentColor.opacity(0.5) : Color.clear),
                       lineWidth: isHighlighted ? 2 : 1)
        )
    }
}

struct SearchModifier: ViewModifier {
    let isInSearchMode: Bool
    let settings: AppSettings
    
    @State private var angle: Double = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: settings.inputBarCornerRadius)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                settings.accentColor,
                                settings.accentColor.opacity(0.7),
                                settings.accentColor.opacity(0.3),
                                settings.accentColor.opacity(0.1),
                                settings.accentColor.opacity(0.1),
                                settings.accentColor.opacity(0.3),
                                settings.accentColor.opacity(0.7),
                                settings.accentColor
                            ]),
                            center: .center,
                            startAngle: .degrees(angle),
                            endAngle: .degrees(angle + 360)
                        ),
                        lineWidth: isInSearchMode ? 3 : 0
                    )
                    .opacity(isInSearchMode ? 1 : 0)
            )
            .onChange(of: isInSearchMode) { newValue in
                if newValue {
                    withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                        angle = 360
                    }
                } else {
                    angle = 0
                }
            }
    }
}

extension View {
    func searchEffect(isInSearchMode: Bool, settings: AppSettings) -> some View {
        self.modifier(SearchModifier(isInSearchMode: isInSearchMode, settings: settings))
    }
}
