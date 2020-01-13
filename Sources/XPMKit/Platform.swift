public enum Platform: String, CaseIterable {
    case iOS = "ios"
    case iPhoneSimulator = "iphonesimulator"
    case macOS = "macos"
    case macCatalyst = "maccatalyst"
    case watchOS = "watchos"
    case watchOSSimulator = "watchossimulator"
    case tvOS = "tvos"
    case tvOSSimulator = "tvossimulator"

    private static let constants: [Platform: (sdk: String, destination: String)] = [
        .iOS:               ("iphoneos",            "generic/platform=iOS"),
        .iPhoneSimulator:   ("iphonesimulator",     "generic/platform=iOS Simulator"),
        .macOS:             ("macosx",              "generic/platform=OS X"),
        .macCatalyst:       ("macosx",              "generic/platform=OS X,variant=Mac Catalyst"),
        .watchOS:           ("watchos",             "generic/watchOS"),
        .watchOSSimulator:  ("watchsimulator",      "generic/watchOS Simulator"),
        .tvOS:              ("appletvos",           "generic/tvOS"),
        .tvOSSimulator:     ("appletvsimulator",    "generic/tvOS Simulator"),
    ]

    var sdk: String { Self.constants[self]!.sdk }
    var destination: String {Self.constants[self]!.destination }
}
