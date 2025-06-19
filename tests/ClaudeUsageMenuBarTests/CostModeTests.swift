import XCTest
@testable import ClaudeUsageMenuBar

final class CostModeTests: XCTestCase {
    
    func testCostModeEnum() {
        // Test all cases exist
        XCTAssertEqual(CostMode.allCases.count, 3)
        XCTAssertTrue(CostMode.allCases.contains(.auto))
        XCTAssertTrue(CostMode.allCases.contains(.calculate))
        XCTAssertTrue(CostMode.allCases.contains(.display))
        
        // Test raw values
        XCTAssertEqual(CostMode.auto.rawValue, "auto")
        XCTAssertEqual(CostMode.calculate.rawValue, "calculate")
        XCTAssertEqual(CostMode.display.rawValue, "display")
        
        // Test display names
        XCTAssertEqual(CostMode.auto.displayName, "Auto")
        XCTAssertEqual(CostMode.calculate.displayName, "Calculate")
        XCTAssertEqual(CostMode.display.displayName, "Display")
        
        // Test descriptions
        XCTAssertEqual(CostMode.auto.description, "Use costUSD if available, otherwise calculate")
        XCTAssertEqual(CostMode.calculate.description, "Always calculate from current pricing")
        XCTAssertEqual(CostMode.display.description, "Only use pre-calculated costs")
    }
    
    func testCostModeFromRawValue() {
        XCTAssertEqual(CostMode(rawValue: "auto"), .auto)
        XCTAssertEqual(CostMode(rawValue: "calculate"), .calculate)
        XCTAssertEqual(CostMode(rawValue: "display"), .display)
        XCTAssertNil(CostMode(rawValue: "invalid"))
    }
}