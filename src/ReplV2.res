open NodeJs
open CommandLineIOAlg
open DomainLogicAlg
open NewRepl
open Parser
open ParserCombinators

@module("fs") external unlinkSync: string => () = "unlinkSync"

// Here, the library author is the end user... so this is really just putting it all together
// so that package will work as advertised.

// ******************************************
// CommandLineIO instance
// ******************************************

module CommandLineIOAlg = {
  type t = Readline.Interface.t

  let make = () =>
    Readline.make(
        Readline.interfaceOptions(~input=Process.process->Process.stdin, ~output=Process.process->Process.stdout, ()),
    )->CommandLineIO

  let prompt = (CommandLineIO(rl), query, cb) =>
    Promise.make((resolve, _reject) => rl->Readline.Interface.question(query, x => resolve(. x)))
    ->Promise.then(user_input => cb(user_input))

  let on = (CommandLineIO(rl), event, cb) =>
    rl->Readline.Interface.on(Event.fromString(event), cb)->CommandLineIO

  let close = (CommandLineIO(rl)) => rl->Readline.Interface.close
}

// ******************************************
// Rescript REPL Specific Domain Logic instance
// ******************************************

// Initial operations to support:
// - arbitrary rescript code (where if successful the results are appended to a file RescriptRepl.res and npm run res:build is executed
//   if build fails then the file is rolled back to it's previous state; suppress warnings emitted from res:build)
// - multiline mode
// - load a module (if the module has any dependencies, then a tree needs to be built up (to capture the order in which the contents should be written
//   to the RescriptRes file))

// ":{" => StartMultilineMode
// ":}" => EndMultilineMode
// ":load filename.res" => LoadModule(filename.res)
// s => RescriptCode(s)


let parseReplCommand = s => {
    let xs = [
        Parser.parseReplCommand(loadCommandP, s),
        Parser.parseReplCommand(startMultiLineCommandP, s),
        Parser.parseReplCommand(endMultiLineCommandP, s)
    ]
    let ys = Js.Array.filter(x => Belt.Option.isSome(x), xs)

    if Belt.Array.length(ys) == 0 {
        REPLCommands.RescriptCode(s)
    } else {
        switch ys[0] {
            | Some((_, x)) => x
            | _ => Js.Exn.raiseError("INVARIANT VIOLATION: Impossible state, Nones were filtered out of the array prior to this section of the code")
        }
    }
}

module DomainLogicAlg = {
    let handleUserInput = (s: string) => {
        Promise.make((resolve, _reject) => {
            switch parseReplCommand(s) {
                | StartMultiLineMode => {
                    // TODO: Update state to reflect entering multiline mode
                    // will need to modify some state to indicate that future lines should be appended to a string stored on state
                    resolve(. Continue)
                }
                | EndMultiLineMode => {
                    // TODO: Update state to reflect exiting multiline mode and
                    // persist and build entered rescript code
                    // will need to retrieve appended string from state, append it to file and run the res:build/rollback procedure
                    resolve(. Continue)
                }
                | LoadModule(_filename) => {
                    // TODO: Load rescript file and all of the specified dependencies in their necessary order.
                    resolve(. Continue)
                }
                | RescriptCode(_s) => {
                    // TODO
                    resolve(. Continue)
                }
            }

            resolve(. Close)
        })
    }

    let cleanup = () => {
        // https://nodejs.org/api/fs.html#fsaccesssyncpath-mode
        // Don't fancy any of the available functions (that don't require reading line by line) for checking if a file exits.
        // So I'll just do a try/catch here to prevent any error message from bubbling up if these files don't exist.
        // Really not necessary to handle any error that does arise.
        try {
            unlinkSync("./src/RescriptRepl.res")
            unlinkSync("./src/RescriptRepl.bs.js")
            ()
        } catch {
            | _ => ()
        }
    }
}

let run_repl = () => repl(module (CommandLineIOAlg), module (DomainLogicAlg))