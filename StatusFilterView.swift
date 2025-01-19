import SwiftUI

struct StatusFiltersView: View {
    @ObservedObject var viewModel: TaskListViewModel
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(settings.getStatus(for: .task).enumerated()), id: \.element.rawValue) { index, customStatus in
                    let itemStatus = ItemStatus.custom(
                        customStatus.rawValue,
                        colorHex: customStatus.colorHex,
                        customStatus: customStatus
                    )
                    
                    StatusFilterChip(
                        status: itemStatus,
                        isSelected: viewModel.selectedStatusFilter?.rawValue == itemStatus.rawValue,
                        isHighlighted: viewModel.isInSearchMode && viewModel.selectedChipIndex == index,
                        settings: settings
                    ) {
                        viewModel.toggleStatusFilter(itemStatus)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 32)
        .background(settings.backgroundColor)
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
                fontSize: 11
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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
