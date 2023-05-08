open NodeJs
open Parser
open ParserCombinators
open REPLCommands
open DomainLogicAlg

@module("fs") external readFileSync: string => string => string = "readFileSync"
@module("fs") external writeFileSync: string => string => () = "writeFileSync"
external eval: string => () = "eval"

// write("./src/RescriptRepl.res", next_contents)
// build_rescript_code(prev_contents, eval_js_code)

let eval_js_code = () => {
    try {
        let contents = readFileSync("./src/RescriptRepl.bs.js", "utf8")
        eval(contents)
    } catch {
        | _ => Js.log("ERROR: Failed to evalutate code, eval_js_code must not have been able to read RescriptRepl.bs.js")
    }
}

// https://github.com/TheSpyder/rescript-nodejs/blob/main/src/ChildProcess.res#L81
// external exec: (string, (Js.nullable<Js.Exn.t>, Buffer.t, Buffer.t) => unit) => t = "exec"
let build_rescript_code = (prev_contents, f) => {
    ChildProcess.exec("npm run res:build", (error, stdout, stderr) => {
        if (!Js.isNullable(error)) {
            // https://rescript-lang.org/docs/manual/latest/api/js/nullable#bind
            Js.Nullable.bind(error, (. error_str) => {
                switch error_str -> Js.Exn.message {
                    | Some(msg) => {
                        Js.log("ERROR: " ++ msg)
                        // TODO: Will need to see if I can improve highlighting the error later, but for now
                        // this at least outputs whether the build succeeded/failed and will highlight the error
                        // that caused it within the RescriptRepl.res file.
                        Js.log("stdout: " ++ Buffer.toString(stdout))

                        // Rollback to last successful file build
                        writeFileSync("./src/RescriptRepl.res", prev_contents) -> ignore
                    }
                    | None => ()
                }
            }) -> ignore
        } else {
            f()
        }
    })
}



// ---------------------------------------------------------------------

//: Promise.t<cont_or_close<DomainLogicAlg.state<DomainLogicAlg.t>>> => {
let handleContOrClose = (contOrClose, cont, close) => {
    Promise.make((resolve, _reject) => {
        switch contOrClose {
            | Continue(s) => { // : DomainLogicAlg.state<DomainLogicAlg.t>
                cont(s)->Promise.then(_ => Promise.make((res, _rej) => res(. ())))->ignore // the Promise.then becomes necessary because the recursive function is async... now
                resolve(. contOrClose)
            }
            | Close => {
                Js.log("See you Space Cowboy")
                close()
                resolve(. contOrClose)
            }
        }
    })
}

let start_repl = async (make, prompt, close) => {
    let state = make()
    writeFileSync("./src/RescriptRepl.res", "")

    let rec run_loop = async (s) => {
        let contOrClose = await prompt(s)
        await handleContOrClose(contOrClose, run_loop, close)
    }

    await run_loop(state)
}

// NOTE:
// An Alternative instance for option can be used here to prevent having to throw the error for the invariant violation case...
// parseReplCommand(loadCommandP, s) <|> parseReplCommand(startMultiLineCommandP, s) <|> Parser.parseReplCommand(endMultiLineCommandP, s) <|> Some(RescriptCode(s))
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

// I also had a :reset command in the first version which would
// wipe the file clean...
// let parseAndHandleCommands = (state: DomainLogicAlg.state<DomainLogicAlg.t>) => (s: string) => {
    // : DomainLogicAlg.t <- compilation error when annotating state below with this...
let parseAndHandleCommands = (state: domain_logic_state) => (s: string) => {
    Promise.make((resolve, _reject) => {
        switch parseReplCommand(s) {
            | StartMultiLineMode => {
                // TODO: Update state to reflect entering multiline mode
                // will need to modify some state to indicate that future lines should be appended to a string stored on 
                Js.log("StartMultiLineMode")
                resolve(. DomainLogicAlg.Continue(state))
            }
            | EndMultiLineMode => {
                // TODO: Update state to reflect exiting multiline mode and
                // persist and build entered rescript code
                // will need to retrieve appended string from state, append it to file and run the res:build/rollback procedure
                Js.log("EndMultiLineMode")
                resolve(. DomainLogicAlg.Continue(state))
            }
            | LoadModule(_filename) => {
                // TODO: Load rescript file and all of the specified dependencies in their necessary order.
                Js.log("LoadModule")
                resolve(. DomainLogicAlg.Continue(state))
            }
            | RescriptCode(code_str) => {
                // Well... if I take the approach of just straight up doing file IO in here, then I lose testability (of swapping in test instances of anything)
                // For files it's easy enough to see how you'd might create a test instance.
                // For the ReScript build step, it's less so (but I do imagine some function which returns a RescriptBuildStatus = Success | Fail where
                // the function that returns ReScriptBuildStatus could be a prod instance (actually executing the Node ChildProcess npm run res:build command or
                // version which implements a test instance of it in order to be able to test that the rest of the flow results in an expected (domain_logic_state)
                // being yielded in both prod/test scenarios))

                // ^^ Top priority to actually make it that way...
                Js.log("RescriptCode")
                let prev_contents = readFileSync("./src/RescriptRepl.res", "utf8")
                writeFileSync("./src/RescriptRepl.res", prev_contents ++ "\n" ++ code_str)
                build_rescript_code(prev_contents, eval_js_code)->ignore
                
                // TODO: Need to make parsers for these cases
                // cases where the contents of the file will be rolled back even when the build is successful:
                // 1. Js.log....restofstring
                // 2. beginningofstring...->Js.log
                resolve(. DomainLogicAlg.Continue(state))
            }
        }
    })
}

// I guess these would all become first class module arguments to NewRepl.res' repl/2 function? (making it then repl/5...)
// Or should I just straight up have these be passed through the DomainLogicAlg?
// module type FileIO = {
//     let read
//     let write
//     let rollback
// }

// type rescriptBuildResult = BuildSuccess | BuildFail

// module type RescriptBuild = {
//     type t = rescriptBuildResult
//     let build: () => t
// }

// NOTE: In this version, I'd prefer to just passs in the js code string, rather than having to read the file.
// That way it can come directly from a BuildSuccess(js_code_str) result, and elimintate the possibility of eval erroring out.
// module type EvalCode = {
//     let eval: () => ()
// }

// how the build_rescript_code function would look if it was to be used to satisfy the type constaints of RescriptBuild:
// returning a promise becomes necessary here, as the return type of ChildProcess.exec is NodeJs.ChildProcess.t (but double check the source code)
// let build_rescript_code = () => {
//     Promise.make((resolve, _reject) => {
//         ChildProcess.exec("npm run res:build", (error, stdout, stderr) => {
//             if (!Js.isNullable(error)) {
//                 // https://rescript-lang.org/docs/manual/latest/api/js/nullable#bind
//                 Js.Nullable.bind(error, (. error_str) => {
//                     switch error_str -> Js.Exn.message {
//                         | Some(msg) => {
//                             Js.log("ERROR: " ++ msg)
//                             resolve(. BuildFail)
//                         }
//                         | None => resolve(. BuildFail)
//                     }
//                 }) -> ignore
//             } else {
//                 resolve(. BuildSuccess)
//             }
//         })
//     })
// }