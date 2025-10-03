import XCTest
@testable import RevenueCore

final class RevenueCoreTests: XCTestCase {
    func testVersionString() {
        XCTAssertEqual(RevenueCore.version, "0.1.0")
    }
}
