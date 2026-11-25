import XCTest
@testable import TodaysJobs
final class JobTests: XCTestCase {
    func testSampleData() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "jobs", withExtension: "json"))
        let jobs = try Job.decode(Data(contentsOf: url))
        XCTAssertEqual(jobs.count, 5)
        XCTAssertNil(jobs[1].notes)
        XCTAssertEqual(jobs[2].name, "Unknown customer")
        XCTAssertEqual(jobs[4].displayAddress, "No address yet")
        XCTAssertEqual(jobs.filter { $0.status == .pending }.count, 3)
        let date = try XCTUnwrap(jobs[0].date)
        XCTAssertTrue(jobs[0].overdue(at: date.addingTimeInterval(60)))
        XCTAssertFalse(jobs[1].overdue(at: date.addingTimeInterval(86400)))
    }
}

