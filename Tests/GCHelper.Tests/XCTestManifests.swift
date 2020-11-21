import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(GCHelper_Tests.allTests),
    ]
}
#endif
