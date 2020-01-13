import Foundation
import ConsoleKit
import Logging

do {
    let console: Console = Terminal()
    let input = CommandInput(arguments: CommandLine.arguments)

    var commands = Commands()
    commands.use(BuildCommand(), as: "build")
    commands.use(CleanCommand(), as: "clean")

    do {
        try console.run(commands.group(), input: input)
    } catch let error as CustomStringConvertible {
        console.error(error.description)
        exit(1)
    } catch let error {
        console.error(error.localizedDescription)
        exit(1)
    }
}
