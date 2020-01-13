import XPMKit
import Foundation
import ConsoleKit
import TSCBasic
import Logging

final class CleanCommand: Command {
    struct Signature: CommandSignature {
        @Option(name: "package-path")
        var packagePath: String?

        @Flag(name: "verbose")
        var verbose: Bool
    }

    let help = "Clean all intermediate files."

    func run(using context: CommandContext, signature: Signature) throws {
        let logger = Self.makeLogger(console: context.console, verbose: signature.verbose)
        let executor = ProcessExecutor(verbose: signature.verbose)

        let engine = try Engine(
            rootPackagePath: signature.packagePath,
            outputPath: nil,
            executor: executor,
            fileSystem: localFileSystem,
            logger: logger
        )
        try engine.clean()
    }
}
