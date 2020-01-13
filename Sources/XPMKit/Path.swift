import Foundation
import TSCBasic

public struct Path: Codable {
    public let rootPackageDirectory: AbsolutePath
    public let currentDirectoryPath: AbsolutePath
    public let outputDirectoryPath: AbsolutePath?

    public init(rootPackagePath: String?, outputPath: String?, currentDirectoryPath: AbsolutePath) {
        self.currentDirectoryPath = currentDirectoryPath
        self.rootPackageDirectory = AbsolutePath(rootPackagePath ?? ".", relativeTo: currentDirectoryPath)
        if let output = outputPath {
            self.outputDirectoryPath = AbsolutePath(output, relativeTo: currentDirectoryPath)
        } else {
            self.outputDirectoryPath = nil
        }
    }
}

extension Path {
    // MARK: - SwiftPM

    public var buildDirectory: AbsolutePath {
        rootPackageDirectory.appending(components: ".build")
    }

    public var checkoutsDirectory: AbsolutePath {
        buildDirectory.appending(components: "checkouts")
    }

    public var dependenciesStateJSON: AbsolutePath {
        buildDirectory.appending(components: "dependencies-state.json")
    }

    public func subPackageDirectory(for dependency: Dependency) -> AbsolutePath {
        checkoutsDirectory.appending(components: dependency.subpath)
    }

    // MARK: - XPM

    public var xpmDirectory: AbsolutePath {
        currentDirectoryPath.appending(components: ".xpm")
    }

    public var projectsDirectory: AbsolutePath {
        xpmDirectory.appending(components: "projects")
    }

    public func project(for package: Package) -> AbsolutePath {
        projectsDirectory.appending(components: "\(package.versionedName).xcodeproj")
    }

    public func buildDirectory(for package: Package) -> AbsolutePath {
        xpmDirectory.appending(components: "build", package.name)
    }

    public var archivesDirectory: AbsolutePath {
        xpmDirectory.appending(components: "archives")
    }

    public func archive(for package: Package, sdk: String) -> AbsolutePath {
        archivesDirectory.appending(components: package.versionedName, "\(sdk).xcarchive")
    }

    public var derivedDataDirectory: AbsolutePath {
        xpmDirectory.appending(components: "DerivedData")
    }

    public func derivedDataDirectory(for package: Package, sdk: String) -> AbsolutePath {
        derivedDataDirectory.appending(components: package.name, sdk)
    }

    public var frameworksDirectory: AbsolutePath {
        outputDirectoryPath ?? xpmDirectory.appending(components: "frameworks")
    }

    public func xcframework(name: String) -> AbsolutePath {
        frameworksDirectory.appending(components: "\(name).xcframework")
    }

    public func archivedFrameworksDirectory(for package: Package, sdk: String) -> AbsolutePath {
        archive(for: package, sdk: sdk).appending(components: "Products", "Library", "Frameworks")
    }
}
