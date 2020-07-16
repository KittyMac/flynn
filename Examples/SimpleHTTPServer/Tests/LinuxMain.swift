import XCTest

import SimpleHTTPServerTests

var tests = [XCTestCaseEntry]()
tests += SimpleHTTPServerTests.allTests()
XCTMain(tests)
