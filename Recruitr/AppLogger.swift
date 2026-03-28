import Foundation
import OSLog

enum AppLogger {
    private static let subsystem = "com.example.Recruitr"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let ai = Logger(subsystem: subsystem, category: "ai")
    static let data = Logger(subsystem: subsystem, category: "data")
    static let network = Logger(subsystem: subsystem, category: "network")
}
