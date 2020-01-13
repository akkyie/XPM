import XCTest
import Logging
import TSCBasic

@testable import XPMKit

final class EngineTests: XCTestCase {
    func testInit() throws {
        let environment = Environment()
        XCTAssertNoThrow(
            try Engine(
                rootPackagePath: "/root/package/path",
                outputPath: "output",
                executor: environment.executor,
                fileSystem: environment.fileSystem,
                logger: environment.logger
            )
        )
    }

    func testGetPackageInfo() throws {
        let packageInfo = PackageInfo(name: "foo", targets: [])
        let parser = MockParser<PackageInfo>(output: packageInfo)

        do {
            let environment = Environment()

            let result = try environment.engine.getPackageInfo(parser: parser)
            XCTAssertEqual(environment.executor._executedProcesses.map { $0.arguments }, [
                [
                    "swift", "package",
                    "--package-path", "/root/package/path",
                    "dump-package"
                ]
            ])
            XCTAssertEqual(result, packageInfo)
        }
    }

    func testReadDependencies() throws {
        func prepare(_ environment: Environment, _ dependencyNames: [String]) {
            let dependencies = dependencyNames.map { name in Dependency.stub(name) }
            try! environment.fileSystem.writeFileContents(
                environment.path.dependenciesStateJSON
            ) { stream in
                let state = DependencyState(object: Object(dependencies: dependencies), version: 0)
                try! Array(JSONEncoder().encode(state)).write(to: stream)
            }
        }

        let packageInfo = PackageInfo(name: "foo", targets: [
            Target(dependencies: [
                TargetDependency(byName: ["aaa", "abc"]),
            ], name: "a"),
            Target(dependencies: [
                TargetDependency(byName: ["bbb", "bcd"]),
            ], name: "b")
        ])

        do {
            let environment = Environment()
            // Should throw an error if dependencies-state.json does not exist
            XCTAssertThrowsError(try environment.engine.readDependencies(
                targetName: "a",
                packageInfo: packageInfo
            ))
        }

        do {
            let environment = Environment()
            prepare(environment, ["aaa", "abc", "bbb", "bcd"])
            XCTAssertEqual(try environment.engine.readDependencies(
                targetName: "a",
                packageInfo: packageInfo
            ).map { $0.name }, ["aaa", "abc"])
        }

        do {
            let environment = Environment()
            prepare(environment, [])
            XCTAssertThrowsError(try environment.engine.readDependencies(
                targetName: "c",
                packageInfo: packageInfo
            ))
        }
    }

    func testGenerateProjects() throws {
        let packageInfo = PackageInfo.stub("Foo")
        let dependency = Dependency.stub("Bar")

        // MARK: PackageInfo

        do {
            let environment = Environment()
            XCTAssertNoThrow(
                try environment.engine.generateProjects(packages: [packageInfo])
            )
            XCTAssertEqual(environment.executor._executedProcesses.map { $0.arguments }, [
                [
                    "swift", "package",
                    "--package-path", "/root/package/path",
                    "--build-path", "/.xpm/build/Foo",
                    "--force-resolved-versions",
                    "generate-xcodeproj",
                    "--skip-extra-files",
                    "--output", "/.xpm/projects/Foo.xcodeproj"
                ],
            ])
        }

        do {
            let environment = Environment()
            try environment.fileSystem.createDirectory(
                environment.path.project(for: packageInfo),
                recursive: true
            )
            XCTAssertNoThrow(
                try environment.engine.generateProjects(packages: [packageInfo])
            )
            // If the package is a target, should not skip project generation
            XCTAssertEqual(environment.executor._executedProcesses.count, 1)
        }

        // MARK: Dependency

        do {
            let environment = Environment()
            XCTAssertNoThrow(
                try environment.engine.generateProjects(packages: [dependency])
            )
            XCTAssertEqual(environment.executor._executedProcesses.map { $0.arguments }, [
                [
                    "swift", "package",
                    "--package-path", "/root/package/path/.build/checkouts/Bar",
                    "--build-path", "/.xpm/build/Bar",
                    "--force-resolved-versions", "generate-xcodeproj",
                    "--skip-extra-files",
                    "--output", "/.xpm/projects/Bar.123456.xcodeproj"
                ],
            ])
        }

        do {
            let environment = Environment()
            try environment.fileSystem.createDirectory(
                environment.path.project(for: dependency),
                recursive: true
            )
            XCTAssertNoThrow(
                try environment.engine.generateProjects(packages: [dependency])
            )
            // If the package is a dependency, should skip project generation if one exists
            XCTAssertEqual(environment.executor._executedProcesses.count, 0)
        }

        // MARK: Both

        do {
            let environment = Environment()
            XCTAssertNoThrow(
                try environment.engine.generateProjects(packages: [packageInfo, dependency])
            )
            XCTAssertEqual(environment.executor._executedProcesses.count, 2)
        }

        do {
            let environment = Environment()
            try environment.fileSystem.createDirectory(
                environment.path.project(for: packageInfo),
                recursive: true
            )
            try environment.fileSystem.createDirectory(
                environment.path.project(for: dependency),
                recursive: true
            )
            XCTAssertNoThrow(
                try environment.engine.generateProjects(packages: [packageInfo, dependency])
            )
            // Project generation only for target should be skipped
            XCTAssertEqual(environment.executor._executedProcesses.count, 1)
        }
    }

    func testArchive() throws {
        let packageInfo = PackageInfo.stub("Foo")
        let dependency = Dependency.stub("Bar")

        let platforms: [Platform] = [.iOS, .macOS]

        // MARK: PackageInfo

        do {
            let environment = Environment()
            XCTAssertNoThrow(
                try environment.engine.archive(packages: [packageInfo], platforms: platforms)
            )
            assertEqual(environment.executor._executedProcesses.map { $0.arguments }, [
                [
                    "xcodebuild", "archive",
                    "-quiet",
                    "-project", "/.xpm/projects/Foo.xcodeproj",
                    "-scheme", "Foo-Package",
                    "-archivePath", "/.xpm/archives/Foo/iphoneos.xcarchive",
                    "-destination=\"generic/platform=iOS\"",
                    "-sdk", "iphoneos",
                    "-derivedDataPath", "/.xpm/DerivedData/Foo/iphoneos",
                    "SKIP_INSTALL=NO",
                    "BUILD_LIBRARY_FOR_DISTRIBUTION=YES",
                    "COMPILER_INDEX_STORE_ENABLE=NO"
                ],
                [
                    "xcodebuild", "archive",
                    "-quiet",
                    "-project", "/.xpm/projects/Foo.xcodeproj",
                    "-scheme", "Foo-Package",
                    "-archivePath", "/.xpm/archives/Foo/macosx.xcarchive",
                    "-destination=\"generic/platform=OS X\"",
                    "-sdk", "macosx",
                    "-derivedDataPath", "/.xpm/DerivedData/Foo/macosx",
                    "SKIP_INSTALL=NO",
                    "BUILD_LIBRARY_FOR_DISTRIBUTION=YES",
                    "COMPILER_INDEX_STORE_ENABLE=NO"
                ],
            ])
        }

        do {
            let environment = Environment()
            try environment.fileSystem.createDirectory(
                environment.path.archive(for: packageInfo, sdk: "iphoneos"),
                recursive: true
            )
            XCTAssertNoThrow(
                try environment.engine.archive(packages: [packageInfo], platforms: platforms)
            )
            // If the package is a target, should not skip archiving
            XCTAssertEqual(environment.executor._executedProcesses.count, 2)
        }

        // MARK: Dependency

        do {
            let environment = Environment()
            XCTAssertNoThrow(
                try environment.engine.archive(packages: [dependency], platforms: platforms)
            )
            assertEqual(environment.executor._executedProcesses.map { $0.arguments }, [
                [
                    "xcodebuild", "archive",
                    "-quiet",
                    "-project", "/.xpm/projects/Bar.123456.xcodeproj",
                    "-scheme", "Bar-Package",
                    "-archivePath", "/.xpm/archives/Bar.123456/iphoneos.xcarchive",
                    "-destination=\"generic/platform=iOS\"",
                    "-sdk", "iphoneos",
                    "-derivedDataPath", "/.xpm/DerivedData/Bar/iphoneos",
                    "SKIP_INSTALL=NO",
                    "BUILD_LIBRARY_FOR_DISTRIBUTION=YES",
                    "COMPILER_INDEX_STORE_ENABLE=NO"
                ],
                [
                    "xcodebuild", "archive",
                    "-quiet",
                    "-project", "/.xpm/projects/Bar.123456.xcodeproj",
                    "-scheme", "Bar-Package",
                    "-archivePath", "/.xpm/archives/Bar.123456/macosx.xcarchive",
                    "-destination=\"generic/platform=OS X\"",
                    "-sdk", "macosx",
                    "-derivedDataPath", "/.xpm/DerivedData/Bar/macosx",
                    "SKIP_INSTALL=NO",
                    "BUILD_LIBRARY_FOR_DISTRIBUTION=YES",
                    "COMPILER_INDEX_STORE_ENABLE=NO"
                ],
            ])
        }

        do {
            let environment = Environment()
            try environment.fileSystem.createDirectory(
                environment.path.archive(for: dependency, sdk: "iphoneos"),
                recursive: true
            )
            XCTAssertNoThrow(
                try environment.engine.archive(packages: [dependency], platforms: platforms)
            )
            // If the package is a dependency, should skip archiving
            XCTAssertEqual(environment.executor._executedProcesses.count, 1)
        }

        // MARK: Both

        do {
            let environment = Environment()
            try environment.fileSystem.createDirectory(
                environment.path.archive(for: packageInfo, sdk: "iphoneos"),
                recursive: true
            )
            try environment.fileSystem.createDirectory(
                environment.path.archive(for: dependency, sdk: "iphoneos"),
                recursive: true
            )
            XCTAssertNoThrow(
                try environment.engine.archive(packages: [packageInfo, dependency], platforms: platforms)
            )
            // Only for target should be skipped
            XCTAssertEqual(environment.executor._executedProcesses.count, 3)
        }
    }

    func testListFrameworks() throws {
        let packages: [Package] = [
            PackageInfo.stub("Foo"),
            Dependency.stub("Bar")
        ]

        let platforms: [Platform] = [.iOS, .macOS]

        let environment = Environment()

        for platform in platforms {
            let frameworksPath = environment.path.archivedFrameworksDirectory(
                for: packages[0],
                sdk: platform.sdk
            )
            try environment.fileSystem.createDirectory(frameworksPath, recursive: true)
            try environment.fileSystem.createDirectory(
                frameworksPath.appending(component: "Foo.framework"),
                recursive: true
            )
            try environment.fileSystem.createDirectory(
                frameworksPath.appending(component: "FooBar.framework"),
                recursive: true
            )
        }

        for platform in platforms {
            let frameworksPath = environment.path.archivedFrameworksDirectory(
                for: packages[1],
                sdk: platform.sdk
            )
            try environment.fileSystem.createDirectory(frameworksPath, recursive: true)
            try environment.fileSystem.createDirectory(
                frameworksPath.appending(component: "Bar.framework"),
                recursive: true
            )
            try environment.fileSystem.createDirectory(
                frameworksPath.appending(component: "FooBar.framework"),
                recursive: true
            )
        }

        assertEqual(
            try environment.engine.listFrameworks(packages: packages, platforms: platforms),
            [
                "Foo": [
                    AbsolutePath("/.xpm/archives/Foo/macosx.xcarchive/" +
                        "Products/Library/Frameworks/Foo.framework"
                    ),
                    AbsolutePath("/.xpm/archives/Foo/iphoneos.xcarchive/" +
                        "Products/Library/Frameworks/Foo.framework"
                    ),
                ],
                "Bar": [
                    AbsolutePath("/.xpm/archives/Bar.123456/macosx.xcarchive/" +
                        "Products/Library/Frameworks/Bar.framework"
                    ),
                    AbsolutePath("/.xpm/archives/Bar.123456/iphoneos.xcarchive/" +
                        "Products/Library/Frameworks/Bar.framework"
                    ),
                ],
                "FooBar": [
                    AbsolutePath("/.xpm/archives/Foo/macosx.xcarchive/" +
                        "Products/Library/Frameworks/FooBar.framework"
                    ),
                    AbsolutePath("/.xpm/archives/Foo/iphoneos.xcarchive/" +
                        "Products/Library/Frameworks/FooBar.framework"
                    ),
                ],
            ]
        )
    }

    func testGenerateXCFrameworks() throws {
        let frameworks: [String: [AbsolutePath]] = [
            "Foo": [
                AbsolutePath("/a/Foo.framework"),
                AbsolutePath("/b/Foo.framework")
            ]
        ]

        do {
            let environment = Environment()

            XCTAssertNoThrow(
                try environment.engine.generateXCFrameworks(frameworks: frameworks)
            )

            assertEqual(environment.executor._executedProcesses.map { $0.arguments }, [
                [
                    "xcodebuild", "-create-xcframework",
                    "-output", "/.xpm/frameworks/Foo.xcframework",
                    "-framework", "/a/Foo.framework",
                    "-framework", "/b/Foo.framework",
                ],
            ])
        }

        do {
            let environment = Environment(output: "output")

            XCTAssertNoThrow(
                try environment.engine.generateXCFrameworks(frameworks: frameworks)
            )

            assertEqual(environment.executor._executedProcesses.map { $0.arguments }, [
                [
                    "xcodebuild", "-create-xcframework",
                    "-output", "/output/Foo.xcframework",
                    "-framework", "/a/Foo.framework",
                    "-framework", "/b/Foo.framework",
                ],
            ])
        }
    }

    struct Environment {
        let fileSystem = InMemoryFileSystem()
        let executor = MockExecutor()
        let engine: Engine<MockExecutor>
        let logger = Logger(label: "sh.aky.XPMKitTests.logger")

        var path: Path { engine.path }

        init(output: String? = nil) {
            engine = try! Engine(
                rootPackagePath: "/root/package/path",
                outputPath: output,
                executor: executor,
                fileSystem: fileSystem,
                logger: logger
            )
        }
    }
}

final class PlatformTests: XCTestCase {
    func test() throws {
        // Ensure sdks and destinations are defined for all platforms
        for platform in Platform.allCases {
            _ = platform.sdk
            _ = platform.destination
        }
    }
}
