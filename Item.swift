import Foundation
import SwiftUI

struct ItemStatus: Codable, Hashable {
    let rawValue: String
    let isCustom: Bool
    let colorHex: String?
    
    static func custom(_ value: String, colorHex: String) -> ItemStatus {
        ItemStatus(rawValue: value, isCustom: true, colorHex: colorHex)
    }
    
    var isDone: Bool {
        rawValue == "DONE"
    }
    
    var color: Color {
        if let hex = colorHex {
            return Color(hex: hex) ?? .gray
        }
        return .gray
    }
}

struct Item: Identifiable, Codable {
    let id: UUID
    var title: String
    var isCollapsed: Bool
    var status: ItemStatus
    var subItems: [Item]?
    let createdAt: Date
    var modifiedAt: Date
    var completedAt: Date?
    var hierarchyLevel: Int = 0
    
    init(
        id: UUID = UUID(),
        title: String,
        isCollapsed: Bool = false,
        status: ItemStatus? = nil,
        subItems: [Item]? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isCollapsed = isCollapsed
        
        if let status = status {
            self.status = status
        } else if let todoStatus = AppSettings.shared?.getStatus(for: .task).first {
            self.status = .custom(todoStatus.rawValue, colorHex: todoStatus.colorHex)
        } else {
            self.status = .custom("TODO", colorHex: "#007AFF")
        }
        
        self.subItems = subItems
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.completedAt = completedAt
    }
    
    /// Returns true if this item is a task (no sub-items)
    var isTask: Bool {
        subItems == nil || subItems?.isEmpty == true
    }
    
    /// Returns true if this item is a root-level project
    var isProject: Bool {
        !isTask && hierarchyLevel == 0
    }
    
    /// Returns true if this item is a sub-project
    var isSubProject: Bool {
        !isTask && hierarchyLevel > 0
    }
    
    /// Adds a sub-item to this item
    mutating func addSubItem(_ item: Item) {
        if subItems == nil {
            subItems = []
        }
        
        var newItem = item
        newItem.hierarchyLevel = self.hierarchyLevel + 1
        
        subItems?.append(newItem)
        touch()
    }
    
    /// Updates status based on current hierarchy position and children
    mutating func updateStatusBasedOnHierarchy(settings: AppSettings) {
        guard !isTask else { return }
        
        if status.isDone {
            return
        }

        // Se está movendo para nível intermediário (qualquer nível > 0)
        if hierarchyLevel > 0 {
            if let subprojectStatus = settings.getStatus(for: .intermediate).first(where: { $0.rawValue == "SUBPROJECT" }) {
                status = .custom(subprojectStatus.rawValue, colorHex: subprojectStatus.colorHex)
            } else {
                // Fallback para SUBPROJECT padrão
                status = .custom("SUBPROJECT", colorHex: "#808080")
            }
            return
        }
        
        // Se está no nível raiz (nível 0)
        let appropriateStatuses = settings.getStatus(for: .firstLevel)
        if !appropriateStatuses.contains(where: { $0.rawValue == status.rawValue }) {
            if let firstStatus = appropriateStatuses.first {
                status = .custom(firstStatus.rawValue, colorHex: firstStatus.colorHex)
            }
        }
    }
    
    /// Removes a sub-item by its ID
    @discardableResult
    mutating func removeSubItem(id: UUID) throws -> Item {
        guard let index = subItems?.firstIndex(where: { $0.id == id }) else {
            throw ItemError.invalidHierarchyOperation("Sub-item not found")
        }
        
        let removedItem = subItems?.remove(at: index)
        touch()
        
        return removedItem!
    }
    
    /// Moves a sub-item to a new index
    mutating func moveSubItem(fromIndex: Int, toIndex: Int) throws {
        guard let subItems = subItems,
              fromIndex >= 0, fromIndex < subItems.count,
              toIndex >= 0, toIndex < subItems.count else {
            throw ItemError.invalidHierarchyOperation("Invalid index for move operation")
        }
        
        let item = self.subItems!.remove(at: fromIndex)
        self.subItems!.insert(item, at: toIndex)
        touch()
    }
    
    /// Updates the modification date
    mutating func touch() {
        modifiedAt = Date()
    }
}

enum ItemError: Error {
    case invalidHierarchyOperation(String)
}

// Task counting and completion status
extension Item {
    /// Returns the count of completed and total direct tasks
    var taskCounts: (completed: Int, total: Int) {
        guard let subItems = subItems else { return (0, 0) }
        
        let total = subItems.count
        let completed = subItems.filter { item in
            if item.status.isDone {
                return true
            }
            
            if !item.isTask {
                let (completedSub, totalSub) = item.taskCounts
                return completedSub == totalSub && totalSub > 0
            }
            
            return false
        }.count
        
        return (completed, total)
    }
    
    /// Returns true if the item should be marked as done
    var shouldBeMarkedAsDone: Bool {
        guard !isTask else { return status.isDone }
        
        if let subItems = subItems, !subItems.isEmpty {
            let (completed, total) = taskCounts
            return completed == total
        }
        
        return false
    }
    
    /// Updates DONE status recursively based on children
    mutating func updateDoneStatus() {
        if var subItems = subItems {
            for i in subItems.indices {
                subItems[i].updateDoneStatus()
            }
            self.subItems = subItems
        }
        
        if shouldBeMarkedAsDone && !status.isDone {
            if let doneStatus = AppSettings.shared?.getStatus(for: .task)
                .first(where: { $0.rawValue == "DONE" }) {
                status = .custom(doneStatus.rawValue, colorHex: doneStatus.colorHex)
                completedAt = Date()
            }
        }
        else if status.isDone && !shouldBeMarkedAsDone {
            if hierarchyLevel == 0 {
                if let firstStatus = AppSettings.shared?.getStatus(for: .firstLevel).first {
                    status = .custom(firstStatus.rawValue, colorHex: firstStatus.colorHex)
                }
            } else {
                if let firstStatus = AppSettings.shared?.getStatus(for: .intermediate).first {
                    status = .custom(firstStatus.rawValue, colorHex: firstStatus.colorHex)
                }
            }
            completedAt = nil
        }
    }
}
