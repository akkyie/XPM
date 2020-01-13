import Foundation
import TSCBasic

public struct Process: Equatable {
    public let arguments: [String]

    public init(_ arguments: [String]) {
        self.arguments = arguments
    }
}

public protocol Executor {
    typealias Completion<Output> = (Result<Output, Error>) -> Void

    func execute<Parser: OutputParser>(
        processes: [Process],
        parser: Parser
    ) throws -> [Parser.Output]
}

extension Executor {
    public func execute<Parser: OutputParser>(
        process: Process,
        parser: Parser
    ) throws -> Parser.Output {
        try execute(processes: [process], parser: parser)[0]
    }
}

public protocol OutputParser: AnyObject {
    associatedtype Output

    func receive(stdout bytes: [UInt8]) throws
    func receive(stderr bytes: [UInt8]) throws
    func exit() throws -> Output
}

public final class ProcessExecutor: Executor {
    enum NonZeroExit: Error {
        case signalled(Int32)
        case terminated(Int32)
    }

    let verbose: Bool

    let serialQueue = DispatchQueue(
        label: "sh.aky.XPMKit.ProcessExecutor.serialQueue"
    )

    let concurrentQueue = DispatchQueue(
        label: "sh.aky.XPMKit.ProcessExecutor.concurrentQueue",
        attributes: .concurrent
    )

    public init(verbose: Bool = false) {
        self.verbose = verbose
    }

    public func execute<Parser: OutputParser>(
        processes: [Process],
        parser: Parser
    ) throws -> [Parser.Output] {
        var results: [Result<Parser.Output, Error>] = []

        let group = DispatchGroup()

        let completion = { [serialQueue] (result: Result<Parser.Output, Error>) -> Void in
            serialQueue.sync {
                results.append(result)
            }
        }

        let outputRedirection = TSCBasic.Process.OutputRedirection.stream(
            stdout: { [verbose] bytes in
                if verbose {
                    stdoutStream <<< bytes
                    stdoutStream.flush()
                }
                do {
                    try parser.receive(stdout: bytes)
                } catch {
                    completion(.failure(error))
                }
            },
            stderr: { bytes in
                stderrStream <<< bytes
                stderrStream.flush()
                do {
                    try parser.receive(stderr: bytes)
                } catch {
                    completion(.failure(error))
                }
            }
        )

        for process in processes {
            let process = TSCBasic.Process(
                arguments: process.arguments,
                outputRedirection: outputRedirection
            )

            if verbose {
                print("$ \(process.arguments.joined(separator: " "))", to: &stdoutStream)
                stdoutStream.flush()
            }

            concurrentQueue.async(group: group) { [process] in
                do {
                    try process.launch()
                    let result = try process.waitUntilExit()

                    switch result.exitStatus {
                    case .terminated(code: 0):
                        break
                    case let .terminated(code: code):
                        throw NonZeroExit.terminated(code)
                    case let .signalled(signal: signal):
                        throw NonZeroExit.signalled(signal)
                    }

                    let output = try parser.exit()
                    completion(.success(output))
                } catch {
                    completion(.failure(error))
                }
            }
        }

        group.wait()

        return try results.map { try $0.get() }
    }
}

public class JSONParser<Output: Decodable>: OutputParser {
    let stream = BufferedOutputByteStream()

    public init() {}

    public func receive(stdout bytes: [UInt8]) throws {
        stream <<< bytes
    }

    public func receive(stderr bytes: [UInt8]) throws {}

    public func exit() throws -> Output {
        let decoder = JSONDecoder()
        return try decoder.decode(Output.self, from: Data(stream.bytes.contents))
    }
}

public class VoidParser: OutputParser {
    public init() {}
    public func receive(stdout bytes: [UInt8]) throws {}
    public func receive(stderr bytes: [UInt8]) throws {}
    public func exit() throws -> Void {}
}
