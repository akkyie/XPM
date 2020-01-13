import XCTest
import TSCBasic

@testable import XPMKit

final class ProcessExecutorTests: XCTestCase {
    func testOutput() throws {
        do {
            let executor = ProcessExecutor(verbose: true)
            let parser = MockParser<Void>(output: ())
            let process = Process([testScript, "hello to stdout", "1"])
            try executor.execute(process: process, parser: parser)
            assertEqual(parser._receivedStdout, "hello to stdout\n")
            XCTAssertEqual(parser._hasExited, true)
        }

        do {
            let executor = ProcessExecutor(verbose: true)
            let parser = MockParser<Void>(output: ())
            let process = Process([testScript, "hello to stderr", "2"])
            try executor.execute(process: process, parser: parser)
            assertEqual(parser._receivedStderr, "hello to stderr\n")
            XCTAssertEqual(parser._hasExited, true)
        }
    }

    func testError() throws {
        struct TestError: Error {}

        do {
            let executor = ProcessExecutor(verbose: true)
            let parser = MockParser<Void>(output: (), error: TestError())
            let process = Process([testScript, "hello to stdout", "1"])
            do {
                try executor.execute(process: process, parser: parser)
                XCTFail("Should throw an error")
            } catch {
                XCTAssertTrue(error is TestError)
            }
        }

        do {
            let executor = ProcessExecutor(verbose: true)
            let parser = MockParser<Void>(output: (), error: TestError())
            let process = Process([testScript, "hello to stderr", "2"])
            do {
                try executor.execute(process: process, parser: parser)
                XCTFail("Should throw an error")
            } catch {
                XCTAssertTrue(error is TestError)
            }
        }
    }

    private var testScript: String {
        AbsolutePath(#file).parentDirectory.appending(components: "Scripts", "test.sh").pathString
    }
}

final class JSONParserTests: XCTestCase {
    func testDecode() throws {
        struct Object: Codable, Equatable {
            let number: Int
        }

        let object = Object(number: 12345)

        let parser = JSONParser<Object>()

        let data = try JSONEncoder().encode(object)
        try parser.receive(stdout: Array(data))
        try parser.receive(stderr: [])
        let result = try parser.exit()
        XCTAssertEqual(result, object)
    }

    func testError() throws {
        let parser = JSONParser<Object>()
        try parser.receive(stdout: [])
        try parser.receive(stderr: [])
        do {
            _ = try parser.exit()
            XCTFail("Should throw an error")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }
}
