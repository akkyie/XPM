import XPMKit
import Foundation
import ConsoleKit
import TSCBasic
import Logging

final class BuildCommand: Command {
    struct Signature: CommandSignature {
        @Option(name: "output")
        var output: String?

        @Option(name: "dependency-of", short: "d")
        var rootTargetName: String?

        @Option(name: "platforms")
        var platforms: String?

        @Option(name: "package-path")
        var packagePath: String?

        @Flag(name: "verbose")
        var verbose: Bool
    }

    private let concurrentQueue = DispatchQueue(label: "sh.aky.XPM.queue", attributes: .concurrent)

    let help = "Build XCFrameworks from Package.swift."

    func run(using context: CommandContext, signature: Signature) throws {
        let logger = Self.makeLogger(console: context.console, verbose: signature.verbose)
        let executor = ProcessExecutor(verbose: signature.verbose)

        let platforms = try Platform.parse(signature.platforms)

        let engine = try Engine(
            rootPackagePath: signature.packagePath,
            outputPath: signature.output,
            executor: executor,
            fileSystem: localFileSystem,
            logger: logger
        )

        let packageInfo = try engine.getPackageInfo(parser: JSONParser())

        let packages: [Package]
        if let rootTargetName = signature.rootTargetName {
            packages = try engine.readDependencies(
                targetName: rootTargetName,
                packageInfo: packageInfo
            )
        } else {
            packages = [packageInfo]
        }

        try engine.generateProjects(packages: packages)
        try engine.archive(packages: packages, platforms: platforms)
        let frameworks = try engine.listFrameworks(packages: packages, platforms: platforms)
        try engine.generateXCFrameworks(frameworks: frameworks)
    }
}

extension EngineError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .noCurrentWorkingDirectory:
            return "Could not get current working directory."
        case .unknownPlatform(let value):
            return
                "Unknown platform \(value.debugDescription). " +
            "Available platforms: \(Platform.allCases.map { $0.rawValue })"
        case .noPlatformSpecified:
            return "One or more platforms must be specified with --platforms."
        case .noTargetSpecified:
            return "--target option should be followed by a target name."
        case .noTargetFound(let target):
            return "No target found with name `\(target)`."
        }
    }
}
