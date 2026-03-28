import Foundation

class WebhookService {
    static let shared = WebhookService()
    
    private init() {}
    
    func sendNewRecordNotification(record: Record) {
        AppLogger.network.info("Demo mode: skipped external webhook for record \(record.name, privacy: .public)")
    }

    func makeNotificationURL(for record: Record) -> URL? {
        var components = URLComponents(string: DemoEnvironment.webhookPlaceholder)
        components?.queryItems = [
            URLQueryItem(name: "name", value: record.name),
            URLQueryItem(name: "type", value: record.type)
        ]
        return components?.url
    }
}
