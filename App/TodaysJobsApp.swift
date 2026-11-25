import SwiftUI

@main struct TodaysJobsApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

@MainActor final class JobStore: ObservableObject {
    @Published var jobs: [Job] = []
    @Published var error: String?
    private let key = "completedJobIDs.v1"
    init() { load() }
    func load() {
        do {
            guard let url = Bundle.main.url(forResource: "jobs", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
            let saved = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
            jobs = try Job.decode(Data(contentsOf: url)).map { job in
                var j = job; if saved.contains(j.id) { j.status = .completed }; return j
            }.sorted { $0.scheduledAt < $1.scheduledAt }
            error = nil
        } catch { self.error = "Unable to load jobs: \(error.localizedDescription)" }
    }
    func complete(_ id: String) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[i].status = .completed
        UserDefaults.standard.set(jobs.filter { $0.status == .completed }.map(\.id), forKey: key)
    }
}

struct ContentView: View {
    @StateObject private var store = JobStore()
    @State private var pendingOnly = false
    @State private var search = ""
    @State private var searching = false
    @State private var now = Date()
    var filtered: [Job] { store.jobs.filter { j in
        (!pendingOnly || j.status == .pending) && (search.isEmpty || j.name.localizedCaseInsensitiveContains(search) || j.address.localizedCaseInsensitiveContains(search))
    } }
    var day: String {
        guard let date = store.jobs.first?.date else { return "Today's schedule" }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_GB"); f.timeZone = TimeZone(identifier: "Asia/Kolkata"); f.dateFormat = "EEEE, d MMMM"; return f.string(from: date)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Today's Jobs").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                        Text("\(day) · \(store.jobs.filter { $0.status == .pending }.count) pending").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Picker("Job filter", selection: $pendingOnly) { Text("All").tag(false); Text("Pending").tag(true) }.pickerStyle(.segmented)
                    if searching { TextField("Search customer or address", text: $search).textFieldStyle(.roundedBorder).autocorrectionDisabled() }
                    if let error = store.error {
                        ContentUnavailableView { Label("Couldn't load jobs", systemImage: "exclamationmark.triangle") } description: { Text(error) } actions: { Button("Retry") { store.load() } }
                    } else if filtered.isEmpty {
                        ContentUnavailableView("No jobs found", systemImage: "tray", description: Text(pendingOnly ? "No matching pending jobs." : "Try a different search."))
                    } else {
                        VStack(spacing: 0) {
                            ForEach(filtered) { job in
                                NavigationLink(value: job.id) { JobRow(job: job, now: now) }.buttonStyle(.plain)
                                if job.id != filtered.last?.id { Divider().padding(.leading, 16) }
                            }
                        }.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26))
                    }
                }.padding(16)
            }.background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { searching.toggle(); if !searching { search = "" } } label: { Image(systemName: searching ? "xmark.circle" : "magnifyingglass") }.accessibilityLabel(searching ? "Close search" : "Search jobs") } }
            .navigationDestination(for: String.self) { id in JobDetail(store: store, id: id) }
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
        }
    }
}

struct StatusPill: View {
    let job: Job; let now: Date
    var label: String { if job.overdue(at: now) { return "Overdue" }; switch job.status { case .pending: return "Pending"; case .inProgress: return "In progress"; case .completed: return "Completed" } }
    var tint: Color { if job.overdue(at: now) { return .red }; switch job.status { case .pending: return .orange; case .inProgress: return .blue; case .completed: return .green } }
    var body: some View { Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint).padding(.horizontal, 8).padding(.vertical, 3).background(tint.opacity(0.13), in: Capsule()).fixedSize() }
}

struct JobRow: View {
    let job: Job; let now: Date
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(job.name).font(.system(size: 17, weight: job.hasCustomer ? .semibold : .regular)).foregroundStyle(job.hasCustomer ? Color.primary : Color.secondary).lineLimit(1)
                HStack(spacing: 4) { Image(systemName: job.hasAddress ? "mappin.circle" : "mappin.slash").font(.system(size: 12)); Text(job.displayAddress).font(.system(size: 15)).lineLimit(1).truncationMode(.tail) }.foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 5) {
                Text(job.time).font(.system(size: 15, weight: job.overdue(at: now) ? .semibold : .medium)).monospacedDigit().foregroundStyle(job.overdue(at: now) ? Color.red : job.status == .completed ? Color.secondary : Color.primary)
                StatusPill(job: job, now: now)
            }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tertiary)
        }.padding(.horizontal, 16).padding(.vertical, 12).frame(minHeight: 72).contentShape(Rectangle()).accessibilityElement(children: .combine)
    }
}

struct JobDetail: View {
    @ObservedObject var store: JobStore
    let id: String
    @State private var confirm = false
    var body: some View {
        if let job = store.jobs.first(where: { $0.id == id }) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(job.id).font(.caption).foregroundStyle(.secondary)
                        Text(job.name).font(.title2.bold())
                        StatusPill(job: job, now: Date())
                    }.padding(.vertical, 6)
                    LabeledContent { Text(job.displayAddress).multilineTextAlignment(.trailing) } label: { Label("Address", systemImage: "mappin.circle") }
                    LabeledContent { Text(job.scheduledAt) } label: { Label("Scheduled", systemImage: "clock") }
                }
                Section("Notes") { Text(job.displayNotes).foregroundStyle(job.displayNotes == "No notes available" ? Color.secondary : Color.primary) }
                if job.status == .completed { Section { Label("Job completed", systemImage: "checkmark.circle.fill").foregroundStyle(.green) } }
            }.listStyle(.insetGrouped)
            .navigationTitle("Job Details")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if job.status != .completed {
                    Button { confirm = true } label: { Label("Mark as Completed", systemImage: "checkmark.circle").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8) }.buttonStyle(.borderedProminent).padding().frame(maxWidth: .infinity).background(.bar)
                }
            }
            .confirmationDialog("Mark this job as completed?", isPresented: $confirm, titleVisibility: .visible) { Button("Mark as Completed") { store.complete(id) }; Button("Cancel", role: .cancel) {} }
        } else { ContentUnavailableView("Job not found", systemImage: "questionmark.folder") }
    }
}
