import Foundation
import SwiftData

@Model
final class PillRecord {
    var date: Date
    var morningTaken: Bool
    var eveningTaken: Bool

    init(date: Date, morningTaken: Bool = false, eveningTaken: Bool = false) {
        self.date = Calendar.current.startOfDay(for: date)
        self.morningTaken = morningTaken
        self.eveningTaken = eveningTaken
    }
}
