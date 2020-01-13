import XCTest
@testable import XPMKit

func assertEqual<T: Equatable>(
    _ lhs: [[T]], _ rhs: [[T]],
    _ message: @autoclosure () -> String = "",
    file: StaticString = #file, line: UInt = #line
) {
    XCTAssertEqual(
        lhs.count, rhs.count, "Arrays have different sizes. \(message())",
        file: file, line: line
    )
    for (l, r) in zip(lhs, rhs) {
        XCTAssertEqual(l, r, message(), file: file, line: line)
    }
}

func assertEqual<K: Comparable, V: Equatable & Comparable>(
    _ lhs: [K: [V]], _ rhs: [K: [V]],
    _ message: @autoclosure () -> String = "",
    file: StaticString = #file, line: UInt = #line
) {
    let lks = lhs.keys.sorted()
    let rks = rhs.keys.sorted()
    XCTAssertEqual(lks, rks, message(), file: file, line: line)

    let lvs = lks.map { lhs[$0]!.sorted() }
    let rvs = rks.map { rhs[$0]!.sorted() }
    assertEqual(lvs, rvs, message(), file: file, line: line)
}

func assertEqual(
    _ lhs: [UInt8], _ rhs: String,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #file, line: UInt = #line
) {
    XCTAssertEqual(
        String(data: Data(lhs), encoding: .utf8), rhs,
        message(), file: file, line: line
    )
}

final class MockExecutor: Executor {
    var _executedProcesses: [XPMKit.Process] = []

    func execute<Parser: OutputParser>(
        processes: [XPMKit.Process],
        parser: Parser
    ) throws -> [Parser.Output] {
        _executedProcesses += processes
        return processes.map { _ in try! parser.exit() }
    }
}

final class MockParser<Output>: OutputParser {
    let output: Output
    let error: Error?

    var _receivedStdout: [UInt8] = []
    var _receivedStderr: [UInt8] = []
    var _hasExited: Bool = false

    init(output: Output, error: Error? = nil) {
        self.output = output
        self.error = error
    }

    func receive(stdout bytes: [UInt8]) throws {
        if let error = error {
            throw error
        }
        _receivedStdout += bytes
    }

    func receive(stderr bytes: [UInt8]) throws {
        if let error = error {
            throw error
        }
        _receivedStderr += bytes
    }

    func exit() throws -> Output {
        _hasExited = true
        if let error = error {
            throw error
        }
        return output
    }
}

extension Target {
    static let stub = { (name: String) in
        Target(dependencies: [], name: name)
    }
}

extension Dependency {
    static let stub = { (name: String) in
        Dependency(
            packageRef: PackageRef(name: name),
            state: State(checkoutState: CheckoutState(revision: "123456")),
            subpath: name
        )
    }
}

extension PackageInfo {
    static let stub = { (name: String) in
        PackageInfo(name: name, targets: [
            Target(dependencies: [], name: "a"),
            Target(dependencies: [], name: "b"),
            Target(dependencies: [], name: "c")
        ])
    }
}
