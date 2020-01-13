import Foundation
import TSCBasic
import Logging

public enum EngineError: Swift.Error {
    case noCurrentWorkingDirectory
    case unknownPlatform(Substring)
    case noPlatformSpecified
    case noTargetSpecified
    case noTargetFound(String)
}

public final class Engine<E: Executor> {
    let path: Path
    let executor: E
    let fileSystem: FileSystem
    let logger: Logger

    public init(
        rootPackagePath: String?,
        outputPath: String?,
        executor: E,
        fileSystem: FileSystem,
        logger: Logger
    ) throws {
        guard let currentWorkingDirectory = fileSystem.currentWorkingDirectory else {
            throw EngineError.noCurrentWorkingDirectory
        }
        self.path = Path(
            rootPackagePath: rootPackagePath,
            outputPath: outputPath,
            currentDirectoryPath: currentWorkingDirectory
        )
        self.executor = executor
        self.fileSystem = fileSystem
        self.logger = logger
    }

    public func getPackageInfo<Parser: OutputParser>(parser: Parser) throws -> PackageInfo
        where Parser.Output == PackageInfo
    {
        logger.info("Retrieving target information...")

        let process = Process([
            "swift", "package",
            "--package-path", path.rootPackageDirectory.pathString,
            "dump-package"
        ])

        return try executor.execute(
            process: process,
            parser: parser
        )
    }

    public func readDependencies(
        targetName: String,
        packageInfo: PackageInfo
    ) throws -> [Dependency] {
        logger.info("Reading dependencies...")

        guard let target = packageInfo.targets.first(where: { $0.name == targetName }) else {
            throw EngineError.noTargetFound(targetName)
        }

        let process = Process([
            "swift", "package",
            "--package-path", path.rootPackageDirectory.pathString,
            "resolve"
        ])
        try executor.execute(process: process, parser: VoidParser())

        let data = try fileSystem.readFileContents(path.dependenciesStateJSON)
        let decoder = JSONDecoder()
        let dependencyState = try decoder.decode(DependencyState.self, from: Data(data.contents))

        let dependencies = target.dependencies.flatMap { $0.byName }
        return dependencyState.object.dependencies.filter { dependency in
            dependencies.contains(dependency.packageRef.name)
        }
    }

    public func generateProjects(packages: [Package]) throws {
        logger.info("Generating Xcode projects...")

        try fileSystem.createDirectory(path.projectsDirectory, recursive: true)

        let processes: [Process] = try packages.compactMap { [path] package in
            let output = path.project(for: package)

            if package is PackageInfo {
                try fileSystem.removeFileTree(output)
            }

            guard !fileSystem.exists(output) else {
                logger.debug("Skipping \(package.name)")
                return nil
            }

            let packagePath: String
            if package is PackageInfo {
                packagePath = path.rootPackageDirectory.pathString
            } else if let dependency = package as? Dependency {
                packagePath = path.subPackageDirectory(for: dependency).pathString
            } else {
                fatalError("Unknown type: \(type(of: package))")
            }

            return Process([
                "swift", "package",
                "--package-path", packagePath,
                "--build-path", path.buildDirectory(for: package).pathString,
                "--force-resolved-versions",
                "generate-xcodeproj",
                "--skip-extra-files",
                "--output", output.pathString
            ])
        }

        _ = try executor.execute(processes: processes, parser: VoidParser())
    }

    public func archive(packages: [Package], platforms: [Platform]) throws {
        logger.info("Generating archives...")

        try fileSystem.createDirectory(path.archivesDirectory, recursive: true)

        let processes: [Process] = try packages.flatMap { package in
            try platforms.compactMap { platform in
                let output = path.archive(for: package, sdk: platform.sdk)

                if package is PackageInfo {
                    try fileSystem.removeFileTree(output)
                }

                guard !fileSystem.exists(output) else {
                    logger.info("Skipping \(package.name) \(platform)")
                    return nil
                }

                return Process([
                    "xcodebuild", "archive",
                    "-quiet",
                    "-project", path.project(for: package).pathString,
                    "-scheme", package.schemeName,
                    "-archivePath", output.pathString,
                    "-destination=" + platform.destination.debugDescription,
                    "-sdk", platform.sdk,
                    "-derivedDataPath", path.derivedDataDirectory(for: package, sdk: platform.sdk).pathString,
                    "SKIP_INSTALL=NO",
                    "BUILD_LIBRARY_FOR_DISTRIBUTION=YES",
                    "COMPILER_INDEX_STORE_ENABLE=NO"
                ])
            }
        }

        for process in processes { // Run xcodebuild serially
            _ = try executor.execute(process: process, parser: VoidParser())
        }
    }

    public func listFrameworks(
        packages: [Package],
        platforms: [Platform]
    ) throws -> [String: [AbsolutePath]] {
        var frameworks: [String: [Platform: AbsolutePath]] = [:]

        for package in packages {
            for platform in platforms {
                let directoryPath = path.archivedFrameworksDirectory(
                    for: package,
                    sdk: platform.sdk
                )
                let paths = try fileSystem.getDirectoryContents(directoryPath)
                for path in paths {
                    let path = AbsolutePath(path, relativeTo: directoryPath)
                    if frameworks[path.basenameWithoutExt]?[platform] == nil {
                        frameworks[path.basenameWithoutExt, default: [:]][platform] = path
                    }
                }
            }
        }

        return frameworks.mapValues { Array($0.values) }
    }

    public func generateXCFrameworks(frameworks: [String: [AbsolutePath]]) throws {
        logger.info("Generating XCFrameworks...")

        if fileSystem.exists(path.frameworksDirectory) {
            try fileSystem.removeFileTree(path.frameworksDirectory)
        }
        try fileSystem.createDirectory(path.frameworksDirectory, recursive: true)

        let processes: [Process] = frameworks.compactMap { name, paths in
            let outputPath = path.xcframework(name: name)
            guard !fileSystem.exists(outputPath) else {
                logger.debug("Skipping \(name)")
                return nil
            }

            let arguments: [String] = [
                "xcodebuild", "-create-xcframework",
                "-output", outputPath.pathString
            ] + paths.flatMap { ["-framework", $0.pathString] }

            return Process(arguments)
        }

        _ = try executor.execute(processes: processes, parser: VoidParser())
    }

    public func clean() throws {
        do {
            try fileSystem.removeFileTree(path.xpmDirectory)
            logger.info("Successfully cleaned.")
        } catch {
            logger.error("Failed to clean")
        }
    }
}

extension Platform {
    public static func parse(_ platforms: String?) throws -> [Platform] {
        let values = platforms?.split(separator: ",") ?? []
        let platforms = try values.map { value -> Platform in
            guard let platform = Platform(rawValue: value.lowercased()) else {
                throw EngineError.unknownPlatform(value)
            }
            return platform
        }
        guard !platforms.isEmpty else {
            throw EngineError.noPlatformSpecified
        }
        return platforms
    }
}
