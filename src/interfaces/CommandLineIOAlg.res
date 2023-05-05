// So the user can provide Readline.Interface.t, as you want to keep the underlying implementation hidden from the logic that handles the sequencing
// of the commandlineioalg and domainlogicalg function invocations.
type commandLineIO<'a> = CommandLineIO('a)

// well Readline.make returns a Interface.t
module type CommandLineIOAlg = {
    type t

    let make : () => commandLineIO<t>
    let prompt : commandLineIO<t> => string => (string =>  Promise.t<'a>) =>  Promise.t<'a>
    let on : commandLineIO<t> => string => (() => ()) => commandLineIO<t>
    let close : commandLineIO<t> => unit
}
// - Create a ReadLine instance which facilitates receiving from stdin and sending output back to the user via stdout (Readline.make and Readline.interfaceOptions)
//   The test isntance of the stdin and stdout will need to maintain mutable state?
// - Finally, Clean up upon "close" event being initiated via Ctrl+D | Ctrl+C sent by the user

// Rescript REPL Domain specific logic (to be used within handleUserInput)...
// 1. save
// 2. write
// 3. rollback
// 4. unlinkSync (which is NodeJS' delete file essentially...)
// 5. rewrite (implemented in terms of delete and write) replacing contents of a current file with a provided string

// ^^ Refactoring ideation...