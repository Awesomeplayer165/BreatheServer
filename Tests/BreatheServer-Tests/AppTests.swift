@testable import BreatheServer
import XCTVapor

final class AppTests: XCTestCase {
    func testSensors() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try await configure(app)

        try app.test(.GET, "sensors") { res in
            print(res.body.string)
        }
    }
}
