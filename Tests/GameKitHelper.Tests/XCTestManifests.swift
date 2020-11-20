import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(GameKit_swiftTests.allTests),
    ]
}
#endif
