import Logging
import ConsoleKit

final class CommandLogHandler: LogHandler {

    var logLevel: Logger.Level
    var metadata: Logger.Metadata = [:]

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set(newValue) { metadata[key] = newValue }
    }

    private var consoleLogger: ConsoleLogger

    init<C: Command>(label: String, commandType: C.Type, console: Console, verbose: Bool) {
        logLevel = verbose ? .debug : .info
        consoleLogger = ConsoleLogger(label: "\(label).\(commandType)", console: console, level: logLevel)
    }

    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        file: String, function: String, line: UInt
    ) {
        // WORKAROUND:
        let currentMetadata = consoleLogger.metadata
        defer { consoleLogger.metadata = currentMetadata }
        consoleLogger.metadata = metadata ?? [:]

        consoleLogger.log(
            level: level, message: message, metadata: metadata,
            file: file, function: function, line: line
        )
    }
}

extension Command {
    static func makeLogger(console: Console, verbose: Bool = false) -> Logger {
        LoggingSystem.bootstrap {
            CommandLogHandler(label: $0, commandType: Self.self, console: console, verbose: verbose)
        }
        return Logger(label: "sh.aky.XPM")
    }
}
