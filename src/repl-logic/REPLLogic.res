open NodeJs
open Parser
open ParserCombinators
open REPLCommands
open DomainLogicAlg

@module("fs") external readFileSync: string => string => string = "readFileSync"
@module("fs") external writeFileSync: string => string => () = "writeFileSync"
external eval: string => () = "eval"


type rescriptBuildResult = BuildSuccess | BuildFail

module type RescriptBuild = {
    type t = rescriptBuildResult
    let build: () => Promise.t<rescriptBuildResult>
}

// returning a promise becomes necessary here, as the return type of ChildProcess.exec is NodeJs.ChildProcess.t
// https://github.com/TheSpyder/rescript-nodejs/blob/main/src/ChildProcess.res#L81
// external exec: (string, (Js.nullable<Js.Exn.t>, Buffer.t, Buffer.t) => unit) => t = "exec"
let build = () => {
    Promise.make((resolve, _reject) => {
        ChildProcess.exec("npm run res:build", (error, stdout, stderr) => {
            if (!Js.isNullable(error)) {
                // https://rescript-lang.org/docs/manual/latest/api/js/nullable#bind
                Js.Nullable.bind(error, (. error_str) => {
                    switch error_str -> Js.Exn.message {
                        | Some(msg) => {
                            Js.log("ERROR building ReScript code: " ++ msg)
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
        let initialContents = ""
        if isFilepath(s) {
            try {
                readFileSync(s, "utf8")
            } catch {
                | _ => {
                    write(Filepath(s), initialContents)
                    initialContents
                }
            }
        } else {
            write(Filepath(s), initialContents)
            initialContents
        }
    }
}

type javaScriptCode = JavaScriptCode(string)

module type EvalJavaScriptCode = {
    let eval: javaScriptCode => module (FileOperations) => Promise.t<()>
}

// NOTE:
// This version of eval_js_code instead of the above is necessary, because invoking eval from this file results in any
// file lookup via require inside of RescriptREPL.bs.js being done relative to this file's path (REPLLogic.res) context, instead of
// in the context of ./src which is required in order to be able to load modules within the scope of the user's current project.
let eval_js_code = (JavaScriptCode(code), module (FO: FileOperations)) => {
    Promise.make((resolve, _reject) => {
        try {
            FO.write(Filepath("./src/evalJsCode.js"), `eval(\`${code}\`)`)
            
            ChildProcess.exec("node ./src/evalJsCode.js", (error, stdout, stderr) => {
                if (!Js.isNullable(error)) {
                    // https://rescript-lang.org/docs/manual/latest/api/js/nullable#bind
                    Js.Nullable.bind(error, (. error_str) => {
                        switch error_str -> Js.Exn.message {
                            | Some(msg) => {
                                Js.log("ERROR running JavaScript code: " ++ msg)
                                Js.log("stdout: " ++ Buffer.toString(stdout))
                                resolve(. ())
                            }
                            | None => resolve(. ())
                        }
                    }) -> ignore
                } else {
                    Js.log(stdout)
                    resolve(. ())
                }
            })->ignore
        } catch {
            | x => {
                Js.log("ERROR: Failed to evalutate the following JavaScript code: \n" ++ code)
                Js.log("REASON: ")
                Js.log(x)
                resolve(. ())
            }
        }
    })
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
        Parser.runParser(endMultiLineCommandP, s),
        Parser.runParser(resetCommandP, s)
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

// This pattern just kept popping up in this file
let then = (p: Promise.t<'a>, f: 'a => ()): Promise.t<()> => {
    p
    ->Promise.then(x => {
        Promise.make((resolve, _reject) => {
            f(x)
            resolve(. ())
        })
    })
}

let handleBuildAndEval = (code_str, module(FO : FileOperations), module(RB : RescriptBuild), module(EvalJS : EvalJavaScriptCode)) => {
    let prevContents = FO.read(Filepath("./src/RescriptREPL.res"))
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
                    // Changed EvalJS.eval to return a promise, as if you don't wait for the stdout to be printed, then this will prevent the prompt icon
                    // from being displayed.
                    EvalJS.eval(JavaScriptCode(jsCodeStr), module(FO))
                    ->then(_ => {
                        if startsOrEndsWithJsLog(code_str) {
                            FO.write(Filepath("./src/RescriptREPL.res"), prevContents)
                        }
                        resolve(. ())
                    })->ignore
                }
            }
        })
    }) // ->ignore
}

let handleLoadModuleBuildAndEval = (code_str, module(FO : FileOperations), module(RB : RescriptBuild), module(EvalJS : EvalJavaScriptCode)) => {
    let prevContents = FO.read(Filepath("./src/RescriptREPL.res"))
    // The only difference is in this line... so just make a single function which takes a HoF
    FO.write(Filepath("./src/RescriptREPL.res"), code_str)
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
                    // Changed EvalJS.eval to return a promise, as if you don't wait for the stdout to be printed, then this will prevent the prompt icon
                    // from being displayed.
                    EvalJS.eval(JavaScriptCode(jsCodeStr), module(FO))
                    ->then(_ => {
                        if startsOrEndsWithJsLog(code_str) {
                            FO.write(Filepath("./src/RescriptREPL.res"), prevContents)
                        }
                        resolve(. ())
                    })->ignore
                }
            }
        })
    }) // ->ignore
}

let handleEndMultiLineCase = (state: domainLogicState, module (FO: FileOperations), module (RB: RescriptBuild), module (EvalJS: EvalJavaScriptCode)): Promise.t<domainLogicState> => {
    switch state.multilineMode.rescriptCodeInput {
        | Some(codeStr) => {
            handleBuildAndEval(codeStr, module(FO), module(RB), module(EvalJS))
            -> Promise.then(_result => {
                let updatedState = { multilineMode: { active: false, rescriptCodeInput: None }}
                Promise.make((resolve, _reject) => resolve(. updatedState))
            })
        }
        | None => Js.Exn.raiseError("INVARIANT VIOLATION: The EndMultiLineMode case expects for there to be some rescriptCodeInput present.")
    }
}

let handleRescriptCodeCase = (state: domainLogicState, nextCodeStr: string, module(FO : FileOperations), module(RB : RescriptBuild), module(EvalJS : EvalJavaScriptCode)): Promise.t<domainLogicState> => {
    Promise.make((resolve, _reject) => {
        if state.multilineMode.active {
            switch state.multilineMode.rescriptCodeInput {
                | Some(prevCodeStr) => {
                    let updated_state = { multilineMode: { active: true, rescriptCodeInput: Some(prevCodeStr ++ "\n" ++ nextCodeStr) }}
                    resolve(. updated_state)
                }
                | None => Js.log("INVARIANT VIOLATION: The RescriptCode case expects for there to be some rescriptCodeInput present.")
            }
        } else {
            // Without the Promise.then, when a user is entering multiple lines of code in quick succession (+ where some lines contain errors)
            // will cause the rollback to restore potentially invalid code.
            handleBuildAndEval(nextCodeStr, module(FO), module(RB), module(EvalJS))
            ->then(_ => resolve(. state))->ignore
        }
    })
}

let handleLoadModuleCase = (moduleName: string, module (FO: FileOperations), module (RB: RescriptBuild), module (EvalJS: EvalJavaScriptCode)): Promise.t<()> => {
    let codeStr = FO.read(Filepath("./src/RescriptREPL.res"))
    switch Parser.runParser(openModuleSectionP, codeStr) {
        | Some((remainingCodeStr, OpenModuleSection(openModuleSectionStr))) => {
            let nextCodeStr = openModuleSectionStr ++ `open ${moduleName}` ++ remainingCodeStr

            handleLoadModuleBuildAndEval(nextCodeStr, module(FO), module(RB), module(EvalJS))
            -> Promise.then(_result => {
                Promise.make((resolve, _reject) => resolve(. ()))
            })
        }
        | None => {
            // There are currently no 'open Module' declarations beneath the // Module Imports comment, so kick it off here
            let nextCodeStr = `open ${moduleName}` ++ "\n" ++ codeStr

            handleLoadModuleBuildAndEval(nextCodeStr, module(FO), module(RB), module(EvalJS))
            -> Promise.then(_result => {
                Promise.make((resolve, _reject) => resolve(. ()))
            })
        }
    }
}

// I also had a :reset command in the first version which would wipe the file clean...
let parseAndHandleCommands = (state: domainLogicState, s: string, module(FO : FileOperations), module(RB : RescriptBuild), module(EvalJS : EvalJavaScriptCode)) => {
    Promise.make((resolve, _reject) => {
        switch parseReplCommand(s) {
            | StartMultiLineMode => {
                let updatedState = { multilineMode: { active: true, rescriptCodeInput: Some("") }}
                resolve(. DomainLogicAlg.Continue(updatedState))
            }
            | EndMultiLineMode => {
                handleEndMultiLineCase(state, module(FO), module(RB), module(EvalJS))
                ->then(updatedState => resolve(. DomainLogicAlg.Continue(updatedState)))->ignore
            }
            | LoadModule(moduleName) => {
                handleLoadModuleCase(moduleName, module(FO), module(RB), module(EvalJS))
                ->then(_ => resolve(. DomainLogicAlg.Continue(state)))->ignore
            }
            | RescriptCode(nextCodeStr) => {
                handleRescriptCodeCase(state, nextCodeStr, module(FO), module(RB), module(EvalJS))
                ->then(nextState => resolve(. DomainLogicAlg.Continue(nextState)))->ignore
            }
            | Reset => {
                FO.write(Filepath("./src/RescriptREPL.res"), "")
                resolve(. DomainLogicAlg.Continue(state))
            }
        }
    })
}
