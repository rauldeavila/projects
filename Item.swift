import Foundation
import SwiftUI

/// Represents the status of an item in the task management system
struct ItemStatus: Codable, Hashable {
    let rawValue: String
    let isCustom: Bool
    let colorHex: String?  // Adicionamos a cor diretamente no status
    
    // Status padrão
    static let proj = ItemStatus(rawValue: "PROJ", isCustom: false, colorHex: nil)
    static let subProj = ItemStatus(rawValue: "SUB-PROJ", isCustom: false, colorHex: nil)
    static let todo = ItemStatus(rawValue: "TODO", isCustom: false, colorHex: nil)
    static let doing = ItemStatus(rawValue: "DOING", isCustom: false, colorHex: nil)
    static let done = ItemStatus(rawValue: "DONE", isCustom: false, colorHex: nil)
    static let someday = ItemStatus(rawValue: "SOMEDAY", isCustom: false, colorHex: nil)
    static let maybe = ItemStatus(rawValue: "MAYBE", isCustom: false, colorHex: nil)
    static let future = ItemStatus(rawValue: "FUTURE", isCustom: false, colorHex: nil)
    
    static let allCases: [ItemStatus] = [
        .proj, .subProj, .todo, .doing, .done, .someday, .maybe, .future
    ]
    
    var isProjectStatus: Bool {
        self == .proj || self == .subProj
    }
    
    var color: Color {
        if let hex = colorHex {
            return Color(hex: hex) ?? .gray
        }
        
        switch self {
        case ItemStatus.todo: return .blue
        case ItemStatus.doing: return .orange
        case ItemStatus.done: return .green
        case ItemStatus.proj, ItemStatus.subProj: return .white
        case ItemStatus.someday, ItemStatus.maybe, ItemStatus.future: return .gray
        default: return .gray
        }
    }
    
    static func custom(_ value: String, colorHex: String) -> ItemStatus {
        ItemStatus(rawValue: value, isCustom: true, colorHex: colorHex)
    }
}

/// Represents an item in the task management system
/// Can be a task, project, or sub-project depending on its position in the hierarchy
/// Error types for Item operations
enum ItemError: Error {
    case maxNestingLevelExceeded
    case invalidHierarchyOperation(String)
}

/// Represents an item in the task management system
/// Can be a task, project, or sub-project depending on its position in the hierarchy
struct Item: Identifiable, Codable {
    /// Unique identifier for the item
    let id: UUID
    
    /// Title of the item
    var title: String
    
    var isCollapsed: Bool = false
    
    /// Current status of the item
    var status: ItemStatus
    
    /// Optional array of sub-items
    var subItems: [Item]?
    
    /// Creation date of the item
    let createdAt: Date
    
    /// Last modification date of the item
    var modifiedAt: Date
    
    /// Completion date of the item (when marked as done)
    var completedAt: Date?
    
    /// Initialize a new item
    init(
         id: UUID = UUID(),
         title: String,
         isCollapsed: Bool = false,
         status: ItemStatus = .todo,
         subItems: [Item]? = nil,
         createdAt: Date = Date(),
         modifiedAt: Date = Date(),
         completedAt: Date? = nil
     ) {
         self.id = id
         self.title = title
         self.isCollapsed = isCollapsed
         self.status = status
         self.subItems = subItems
         self.createdAt = createdAt
         self.modifiedAt = modifiedAt
         self.completedAt = completedAt
     }
    
    /// Returns the nesting level of this item (0-3)
    var nestingLevel: Int {
        guard let subItems = subItems, !subItems.isEmpty else { return 0 }
        
        let maxSubLevel = subItems.map { $0.nestingLevel }.max() ?? 0
        return maxSubLevel + 1
    }
    
    /// Returns true if this item is a task (no sub-items)
    var isTask: Bool {
        subItems == nil || subItems?.isEmpty == true
    }
    
    /// Updates status based on current hierarchy position and children
    mutating func updateStatusBasedOnHierarchy() {
        // If has children, should be a project or subproject
        if !isTask {
            if nestingLevel == 1 {
                status = status == .done ? .done : .proj
            } else if nestingLevel == 2 {
                status = status == .done ? .done : .subProj
            }
        }
        
        // If all children are done, mark as done
        if !isTask, let subItems = subItems, !subItems.isEmpty {
            let allChildrenDone = subItems.allSatisfy { $0.status == .done }
            if allChildrenDone {
                status = .done
            } else if status == .done {
                // If any child is not done, parent can't be done
                status = nestingLevel == 1 ? .proj : .subProj
            }
        }
    }
    
    /// Returns true if this item is a project (has sub-items)
    var isProject: Bool {
        !isTask && nestingLevel == 1
    }
    
    /// Returns true if this item is a sub-project
    var isSubProject: Bool {
        !isTask && nestingLevel == 2
    }
    
    /// Maximum allowed nesting level
    static let maxNestingLevel = 3
    
    /// Adds a sub-item to this item
    /// - Parameter item: The item to add as a sub-item
    /// - Throws: ItemError if adding the item would exceed the maximum nesting level
    mutating func addSubItem(_ item: Item) throws {
        // Calculate what would be the new nesting level
        let potentialNewLevel = max(nestingLevel, item.nestingLevel + 1)
        
        // Check if adding this item would exceed the maximum nesting level
        guard potentialNewLevel <= Self.maxNestingLevel else {
            throw ItemError.maxNestingLevelExceeded
        }
        
        // Initialize subItems if nil
        if subItems == nil {
            subItems = []
        }
        
        // Add the item and update modification date
        subItems?.append(item)
        touch()
    }
    
    /// Removes a sub-item by its ID
    /// - Parameter id: The ID of the sub-item to remove
    /// - Returns: The removed item if found
    /// - Throws: ItemError if the item is not found
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
    /// - Parameters:
    ///   - fromIndex: Current index of the sub-item
    ///   - toIndex: Desired new index for the sub-item
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
    
    /// Marks the item as done
    mutating func markAsDone() {
        status = .done
        completedAt = Date()
        touch()
    }
}

extension ItemStatus: Equatable {
    static func == (lhs: ItemStatus, rhs: ItemStatus) -> Bool {
        lhs.rawValue == rhs.rawValue && lhs.isCustom == rhs.isCustom
    }
}

extension ItemStatus {
    var category: StatusCategory {
        if isCustom {
            // Para status customizados, precisamos buscar a categoria no AppSettings
            // Isso será implementado depois
            return .task
        }
        
        switch self {
        case .proj:
            return .firstLevel
        case .subProj:
            return .intermediate
        default:
            return .task
        }
    }
    
    var isHierarchyStatus: Bool {
        category == .firstLevel || category == .intermediate
    }
}

extension Item {
    /// Returns the count of completed and total direct tasks
    var taskCounts: (completed: Int, total: Int) {
        guard let subItems = subItems else { return (0, 0) }
        
        let total = subItems.count
        let completed = subItems.filter { item in
            switch item.status {
            case .done:
                return true
            case .proj, .subProj:
                // For projects and subprojects, only count as done if all their tasks are done
                let (completedSub, totalSub) = item.taskCounts
                return completedSub == totalSub && totalSub > 0
            default:
                return false
            }
        }.count
        
        return (completed, total)
    }
}
