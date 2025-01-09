import SwiftUI

extension Array {
    var nilIfEmpty: Self? {
        isEmpty ? nil : self
    }
}
