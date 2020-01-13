import Foundation
import TSCBasic

// MARK: - Target

public struct PackageInfo: Equatable, Codable {
    public let name: String
    public let targets: [Target]
}

public struct Target: Equatable, Codable {
    public let dependencies: [TargetDependency]
    public let name: String
}

public struct TargetDependency: Equatable, Codable {
    public let byName: [String]
}

// MARK: - Dependency

public struct DependencyState: Equatable, Codable {
    public let object: Object
    public let version: Int
}

public struct Object: Equatable, Codable {
    public let dependencies: [Dependency]
}

public struct Dependency: Equatable, Codable {
    public let packageRef: PackageRef
    public let state: State
    public let subpath: String
}

public struct PackageRef: Equatable, Codable {
    public let name: String
}

public struct State: Equatable, Codable {
    public let checkoutState: CheckoutState
}

public struct CheckoutState: Equatable, Codable {
    public let revision: String
}

// MARK: - Package

public protocol Package {
    var name: String { get }
    var versionedName: String { get }
}

extension Package {
    public var schemeName: String {
        "\(name)-Package"
    }
}

extension PackageInfo: Package {
    public var versionedName: String {
        name
    }
}

extension Dependency: Package {
    public var name: String {
        packageRef.name
    }

    public var versionedName: String {
        "\(packageRef.name).\(state.checkoutState.revision.prefix(8))"
    }
}
