open NodeJs
open Parser
open ParserCombinators
open REPLCommands
open DomainLogicAlg

@module("fs") external readFileSync: string => string => string = "readFileSync"
@module("fs") external writeFileSync: string => string => () = "writeFileSync"
external eval: string => () = "eval"

// https://github.com/TheSpyder/rescript-nodejs/blob/main/src/ChildProcess.res#L81
// external exec: (string, (Js.nullable<Js.Exn.t>, Buffer.t, Buffer.t) => unit) => t = "exec"
// let build_rescript_code = (prev_contents, f) => {
//     // NOTE: I thought there was a way to suppress warnings, but that doesn't seem to be the case.
//     // https://rescript-lang.org/docs/manual/latest/build-overview
//     ChildProcess.exec("npm run res:build", (error, stdout, stderr) => {
//         if (!Js.isNullable(error)) {
//             // https://rescript-lang.org/docs/manual/latest/api/js/nullable#bind
//             Js.Nullable.bind(error, (. error_str) => {
//                 switch error_str -> Js.Exn.message {
//                     | Some(msg) => {
//                         Js.log("ERROR: " ++ msg)
//                         // TODO: Will need to see if I can improve highlighting the error later, but for now
//                         // this at least outputs whether the build succeeded/failed and will highlight the error
//                         // that caused it within the RescriptRepl.res file.
//                         Js.log("stdout: " ++ Buffer.toString(stdout))

//                         // Rollback to last successful file build
//                         writeFileSync("./src/RescriptRepl.res", prev_contents) -> ignore
//                     }
//                     | None => ()
//                 }
//             }) -> ignore
//         } else {
//             f()
//         }
//     })
// }

type rescriptBuildResult = BuildSuccess | BuildFail

module type RescriptBuild = {
    type t = rescriptBuildResult
    let build: () => Promise.t<rescriptBuildResult>
}

// returning a promise becomes necessary here, as the return type of ChildProcess.exec is NodeJs.ChildProcess.t (but double check the source code)
let build = () => {
    Promise.make((resolve, _reject) => {
        ChildProcess.exec("npm run res:build", (error, stdout, stderr) => {
            if (!Js.isNullable(error)) {
                // https://rescript-lang.org/docs/manual/latest/api/js/nullable#bind
                Js.Nullable.bind(error, (. error_str) => {
                    switch error_str -> Js.Exn.message {
                        | Some(msg) => {
                            Js.log("ERROR: " ++ msg)
                            Js.log("stdout: " ++ Buffer.toString(stdout))
                            resolve(. BuildFail)
                        }
                        | None => resolve(. BuildFail)
                    }
                }) -> ignore
            } else {
                resolve(. BuildSuccess)
            }
        })->ignore
    })
}

module RescriptBuild = {
    type t = rescriptBuildResult
    let build = build
}

// NOTE: In this version, I'd prefer to just passs in the js code string, rather than having to read the file.
// That way it can come directly from a BuildSuccess(js_code_str) result, and elimintate the possibility of eval erroring out.

// I guess these would all become first class module arguments to NewRepl.res' repl/2 function? (making it then repl/5...)
// Or should I just straight up have these be passed through the DomainLogicAlg?
type filepath = Filepath(string)

module type FileOperations = {
    let read: filepath => string
    let write: filepath => string => ()
}

let isFilepath = (s: string): bool => {
    switch Parser.runParser(rescriptJavascriptFileP, s) {
        | Some(_) => true
        | None => false
    }
}

module FileOperations = {
    let write = (Filepath(s), contents) => writeFileSync(s, contents)
    // if read fails, then just create ReScriptREPL.res and then return the empty string
    let read = (Filepath(s)) => {
        // So long as the string passed in refers to a filepath, then the only case
        // which throws an exception is where the file doesn't exist.
        if isFilepath(s) {
            try {
                readFileSync(s, "utf8")
            } catch {
                | _ => {
                    write(Filepath(s), "")
                    ""
                }
            }
        } else {
            write(Filepath(s), "")
            ""
        }
    }
}

type javaScriptCode = JavaScriptCode(string)

module type EvalJavaScriptCode = {
    let eval: javaScriptCode => ()
}

let eval_js_code = (JavaScriptCode(code)) => {
    try {
        eval(code)
    } catch {
        | _ => Js.log("ERROR: Failed to evalutate the following JavaScript code: \n" ++ code)
    }
}

module EvalJavaScriptCode = {
    let eval = eval_js_code
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
        Parser.runParser(loadCommandP, s),
        Parser.runParser(startMultiLineCommandP, s),
        Parser.runParser(endMultiLineCommandP, s)
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

let startsOrEndsWithJsLog = (s: string): bool => {
    switch Parser.runParser(rescriptCodeStartsOrEndsWithJsLogP, s) {
        | Some(_) => true
        | None => false
    }
}

let handleBuildAndEval = (code_str, module(FO : FileOperations), module(RB : RescriptBuild), module(EvalJS : EvalJavaScriptCode)) => {
    let prevContents = FO.read(Filepath("src/RescriptREPL.res"))
    FO.write(Filepath("./src/RescriptREPL.res"), prevContents ++ "\n" ++ code_str)
    RB.build()
    -> Promise.then(result => {
        Promise.make((resolve, _reject) => {
            switch result {
                | BuildFail => {
                    // Rolling back the contents of RescriptREPL.res to the previous contents
                    FO.write(Filepath("./src/RescriptREPL.res"), prevContents)
                    resolve(. ())
                }
                | BuildSuccess => {
                    let jsCodeStr = FO.read(Filepath("./src/RescriptREPL.bs.js"))
                    EvalJS.eval(JavaScriptCode(jsCodeStr))
                    if startsOrEndsWithJsLog(code_str) {
                        FO.write(Filepath("./src/RescriptREPL.res"), prevContents)
                    }
                    resolve(. ())
                }
            }
        })
    })->ignore
}

// I also had a :reset command in the first version which would wipe the file clean...
let parseAndHandleCommands = (state: domain_logic_state, s: string, module(FO : FileOperations), module(RB : RescriptBuild), module(EvalJS : EvalJavaScriptCode)) => {
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
                handleBuildAndEval(code_str, module(FO), module(RB), module(EvalJS))
                resolve(. DomainLogicAlg.Continue(state))
            }
        }
    })
}
