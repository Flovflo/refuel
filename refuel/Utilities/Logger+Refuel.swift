import Foundation
import OSLog

extension Logger {
    nonisolated private static var subsystem: String {
        Bundle.main.bundleIdentifier ?? "refuel"
    }

    nonisolated static let refuel = Logger(subsystem: subsystem, category: "app")
    nonisolated static let network = Logger(subsystem: subsystem, category: "network")
    nonisolated static let persistence = Logger(subsystem: subsystem, category: "persistence")
    nonisolated static let location = Logger(subsystem: subsystem, category: "location")
}
