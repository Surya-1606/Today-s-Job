import Foundation

enum JobStatus: String, Codable { case pending, inProgress = "in_progress", completed }
struct Job: Codable, Identifiable {
    let id: String
    let customerName: String?
    let address: String
    let scheduledAt: String
    var status: JobStatus
    let notes: String?
    enum CodingKeys: String, CodingKey {
        case id, address, status, notes
        case customerName = "customer_name", scheduledAt = "scheduled_at"
    }
    var hasCustomer: Bool { !(customerName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
    var name: String { hasCustomer ? (customerName ?? "Unknown customer") : "Unknown customer" }
    var hasAddress: Bool { !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var displayAddress: String { hasAddress ? address : "No address yet" }
    var displayNotes: String { notes.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 } ?? "No notes available" }
    var time: String { String(scheduledAt.suffix(5)) }
    var date: Date? {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "Asia/Kolkata"); f.dateFormat = "yyyy-MM-dd HH:mm"; return f.date(from: scheduledAt)
    }
    func overdue(at now: Date) -> Bool { status == .pending && (date.map { $0 < now } ?? false) }
    static func decode(_ data: Data) throws -> [Job] { try JSONDecoder().decode([Job].self, from: data) }
}
