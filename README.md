# XPM

![Swift 5.1](https://img.shields.io/badge/language-Swift%205.1-orange)
![Swift Package Manager](https://img.shields.io/badge/SwiftPM-compatible-orange.svg)
[![GitHub Actions](https://github.com/akkyie/XPM/workflows/Tests/badge.svg)](https://github.com/akkyie/XPM/actions)

Generate XCFrameworks from Swift Package Manager dependency.

XPM utilizes Swift Package Manager to resolve the dependency graph 
and checking repositories out.
Packages/frameworks maintainers have to do nothing other than putting Package.swift in the repository.

## Usage

When you have a package:
```swift
let package = Package(
    name: "Some",
    dependencies: [
        .package(url: "https://github.com/Foo/Foo.git", from: "..."),
        .package(url: "https://github.com/Bar/Bar.git", from: "..."),
    ],
    targets: [
        .target(
            name: "SomeKit",
            dependencies: ["Foo"]
        ),
        .target(
            name: "SomeCore",
            dependencies: ["Bar"]
        ),
    ]
)
```

### Build XCFrameworks from the package

Run `xpm build` to export `SomeKit.xcframework` and `SomeCore.xcframework`,
along with `Foo.xcframework` and `Bar.xcframework`.

```sh
$ swift run xpm build --platforms ios,iphonesimulator,macos --output Frameworks
```

### Build XCFrameworks from dependencies of a target

Run `xpm build` with `--dependency-of <targetName>` option to export 
just `Foo.xcframework`.

```sh
$ swift run xpm build --dependency-of SomeKit --platforms ios,iphonesimulator,macos --output Frameworks
```
