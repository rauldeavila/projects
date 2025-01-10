import SwiftData
import SwiftUI

@Model
final class ItemModel {
    var id: UUID
    var title: String
    var isCollapsed: Bool
    var statusRawValue: String
    var statusIsCustom: Bool
    var statusColorHex: String?
    var createdAt: Date
    var modifiedAt: Date
    var completedAt: Date?
    @Relationship(deleteRule: .cascade) var subItems: [ItemModel]?
    
    init(
        id: UUID = UUID(),
        title: String,
        isCollapsed: Bool = false,
        status: ItemStatus,
        subItems: [ItemModel]? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isCollapsed = isCollapsed
        self.statusRawValue = status.rawValue
        self.statusIsCustom = status.isCustom
        self.statusColorHex = status.colorHex
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.completedAt = completedAt
        self.subItems = subItems
    }
    
    var status: ItemStatus {
        get {
            if statusIsCustom {
                return .custom(statusRawValue, colorHex: statusColorHex ?? "#808080")
            } else {
                return ItemStatus.allCases.first { $0.rawValue == statusRawValue } ?? .todo
            }
        }
        set {
            statusRawValue = newValue.rawValue
            statusIsCustom = newValue.isCustom
            statusColorHex = newValue.colorHex
        }
    }
}

@Model
final class AppData {
    var selectedColorName: String
    var statusStyle: Int
    var customColors: [CustomColor]
    var customStatus: [CustomStatus]
    
    init(
        selectedColorName: String = "System",
        statusStyle: Int = 0,
        customColors: [CustomColor] = [],
        customStatus: [CustomStatus] = []
    ) {
        self.selectedColorName = selectedColorName
        self.statusStyle = statusStyle
        self.customColors = customColors
        self.customStatus = customStatus
    }
}
