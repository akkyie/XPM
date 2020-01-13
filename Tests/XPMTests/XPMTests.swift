import XCTest
import TSCBasic

final class XPMTests: XCTestCase {
    func testBuild() throws {
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(ProcessInfo().globallyUniqueString)

        let xpmURL = productsDirectory.appendingPathComponent("xpm")
        let process = TSCBasic.Process(arguments: [
            xpmURL.path, "build",
            "--package-path", exampleDirectory.path,
            "--platforms", "macOS",
            "--dependency-of", "Example1",
            "--output", tmpURL.path,
        ], outputRedirection: .stream(
            stdout: { print(String(data: Data($0), encoding: .utf8) ?? "", terminator: "") },
            stderr: { print(String(data: Data($0), encoding: .utf8) ?? "", terminator: "") }
        ))

        try process.launch()
        let result = try process.waitUntilExit()

        guard case .terminated(0) = result.exitStatus else {
            return XCTFail()
        }

        let xcframeworks = try FileManager.default.contentsOfDirectory(atPath: tmpURL.path)
        XCTAssertEqual(xcframeworks, ["Alamofire.xcframework"])
    }

    func testBuildOnlyDependencies() throws {
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(ProcessInfo().globallyUniqueString)

        let xpmURL = productsDirectory.appendingPathComponent("xpm")
        let process = TSCBasic.Process(arguments: [
            xpmURL.path, "build",
            "--package-path", exampleDirectory.path,
            "--platforms", "macOS",
            "--output", tmpURL.path,
        ], outputRedirection: .stream(
            stdout: { print(String(data: Data($0), encoding: .utf8) ?? "", terminator: "") },
            stderr: { print(String(data: Data($0), encoding: .utf8) ?? "", terminator: "") }
        ))

        try process.launch()
        let result = try process.waitUntilExit()

        guard case .terminated(0) = result.exitStatus else {
            return XCTFail()
        }

        let xcframeworks = try FileManager.default.contentsOfDirectory(atPath: tmpURL.path)
        XCTAssertEqual(xcframeworks, [
            "Alamofire.xcframework",
            "Moya.xcframework",
            "GRDB.xcframework",
            "Example2.xcframework",
            "Example1.xcframework",
        ])
    }

    private var productsDirectory: URL {
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
    }

    private var exampleDirectory: URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Example")
    }
}
