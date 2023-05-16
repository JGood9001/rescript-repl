open NodeJs
// open Parser
// open ParserCombinators
// open REPLCommands
// open DomainLogicAlg

@module("fs") external readFileSync: string => string => string = "readFileSync"
@module("fs") external writeFileSync: string => string => () = "writeFileSync"
external eval: string => () = "eval"

type openModulesSectionSplit = { "openModulesSection": string, "remainingStr": string }
@module("../utils/RegexUtils.bs.js") external separateOpenModulesFromRemainingCode: string => openModulesSectionSplit = "separateOpenModulesFromRemainingCode"

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
    // switch Parser.runParser(rescriptJavascriptFileP, s) {
    //     | Some(_) => true
    //     | None => false
    // }

    let rescriptFileRegex = %re("/.res/g")
    let jsFileRegex = %re("/.js/g")

    (Js.Re.test_(rescriptFileRegex, s) || Js.Re.test_(jsFileRegex, s))
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
    let eval: javaScriptCode => module (FileOperations) => Promise.t<option<string>>
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
                                resolve(. None)
                            }
                            | None => resolve(. None)
                        }
                    }) -> ignore
                } else {
                    resolve(. Some(stdout->NodeJs.Buffer.toString->Js.String.trim))
                }
            })->ignore
        } catch {
            | x => {
                Js.log("ERROR: Failed to evalutate the following JavaScript code: \n" ++ code)
                Js.log("REASON: ")
                Js.log(x)
                resolve(. None)
            }
        }
    })
}

module EvalJavaScriptCode = {
    let eval = eval_js_code
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

let handleBuildAndEval = async (codeStr, module(FO : FileOperations), module(RB : RescriptBuild), module(EvalJS : EvalJavaScriptCode)) => {
    let prevContents = FO.read(Filepath("./src/RescriptREPL.res"))
    FO.write(Filepath("./src/RescriptREPL.res"), prevContents ++ "\n" ++ codeStr)
    let result = await RB.build()
    
    switch result {
        | BuildFail => {
            // Rolling back the contents of RescriptREPL.res to the previous contents
            FO.write(Filepath("./src/RescriptREPL.res"), prevContents)
            None
        }
        | BuildSuccess => {
            let jsCodeStr = FO.read(Filepath("./src/RescriptREPL.bs.js"))
            // Changed EvalJS.eval to return a promise, as if you don't wait for the stdout to be printed, then this will prevent the prompt icon from being displayed.
            let stdout = await EvalJS.eval(JavaScriptCode(jsCodeStr), module(FO))
            let startsWithJsLogRegex = %re("/^Js.log/g")
            let endsWithJsLogRegex = %re("/->(\x20*)Js.log(.*)/g")

            if (Js.Re.test_(startsWithJsLogRegex, codeStr) || Js.Re.test_(endsWithJsLogRegex, codeStr)) {
                FO.write(Filepath("./src/RescriptREPL.res"), prevContents)
            }
            stdout
        }
    }
}

let handleLoadModuleBuildAndEval = (codeStr, module(FO : FileOperations), module(RB : RescriptBuild), module(EvalJS : EvalJavaScriptCode)) => {
    let prevContents = FO.read(Filepath("./src/RescriptREPL.res"))
    // The only difference is in this line... so just make a single function which takes a HoF
    FO.write(Filepath("./src/RescriptREPL.res"), codeStr)
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
                        let startsWithJsLogRegex = %re("/^Js.log/g")
                        let endsWithJsLogRegex = %re("/->(\x20*)Js.log(.*)/g")

                        if (Js.Re.test_(startsWithJsLogRegex, codeStr) || Js.Re.test_(endsWithJsLogRegex, codeStr)) {
                            FO.write(Filepath("./src/RescriptREPL.res"), prevContents)
                        }
                        resolve(. ())
                    })->ignore
                }
            }
        })
    }) // ->ignore
}

// let handleEndMultiLineCase = (state: domainLogicState, module (FO: FileOperations), module (RB: RescriptBuild), module (EvalJS: EvalJavaScriptCode)): Promise.t<domainLogicState> => {
//     switch state.multilineMode.rescriptCodeInput {
//         | Some(codeStr) => {
//             handleBuildAndEval(codeStr, module(FO), module(RB), module(EvalJS))
//             -> Promise.then(_result => {
//                 let updatedState = { multilineMode: { active: false, rescriptCodeInput: None }}
//                 Promise.make((resolve, _reject) => resolve(. updatedState))
//             })
//         }
//         | None => Js.Exn.raiseError("INVARIANT VIOLATION: The EndMultiLineMode case expects for there to be some rescriptCodeInput present.")
//     }
// }

// let handleRescriptCodeCase = (state: domainLogicState, nextCodeStr: string, module(FO : FileOperations), module(RB : RescriptBuild), module(EvalJS : EvalJavaScriptCode)): Promise.t<domainLogicState> => {
//     Promise.make((resolve, _reject) => {
//         if state.multilineMode.active {
//             switch state.multilineMode.rescriptCodeInput {
//                 | Some(prevCodeStr) => {
//                     let updated_state = { multilineMode: { active: true, rescriptCodeInput: Some(prevCodeStr ++ "\n" ++ nextCodeStr) }}
//                     resolve(. updated_state)
//                 }
//                 | None => Js.log("INVARIANT VIOLATION: The RescriptCode case expects for there to be some rescriptCodeInput present.")
//             }
//         } else {
//             // Without the Promise.then, when a user is entering multiple lines of code in quick succession (+ where some lines contain errors)
//             // will cause the rollback to restore potentially invalid code.
//             handleBuildAndEval(nextCodeStr, module(FO), module(RB), module(EvalJS))
//             ->then(_ => resolve(. state))->ignore
//         }
//     })
// }

// Replacing the parser combinator with regex
// https://rescript-lang.org/docs/manual/latest/api/js/re#lastindex

// Have only been able to get it to match a single line, so I'll just have to use a loop and slice the string (immutable)
// to retrieve the open module section.
// > let re = %re("/(^open(\x20*)[^A-Z][A-Za-z0-9]*\n)/g")
// ''
// > Js.log(Js.Re.exec_(re, "open ModuleName"))
// "[ 'open', index: 0, input: 'open ModuleName', groups: undefined ]"
// > Js.Re.exec_(re, "open ModuleName")->ignore->(() => Js.log(Js.Re.lastIndex(re)))
// '4'

// Now if I can just match multiple lines which start with open and end with a newline
// then I can get the index where I need to split at for the (openModuleSection, remainingCodeStr)

// This compiles to JS, but the evaluation of the resulting code results in an error...
// > let re = %re("/(^open(\x20*)[^A-Z][A-Za-z0-9]*\n)/")
// ERROR running JavaScript code: Command failed: node ./src/evalJsCode.js
// undefined:5
// var re = /(^open( *)[^A-Z][A-Za-z0-9]*
//          ^

// SyntaxError: Invalid regular expression: missing /

// The javascript it generates:
// var re = /(^open(\x20*)[^A-Z][A-Za-z0-9]*\n)/;

// which works fine when I run it in a node repl
// > var re = /(^open(\x20*)[^A-Z][A-Za-z0-9]*\n)/;
// > re.test("open ModuleName\n")
// true
let handleLoadModuleCase = (moduleName: string, module (FO: FileOperations), module (RB: RescriptBuild), module (EvalJS: EvalJavaScriptCode)): Promise.t<()> => {
    let codeStr = FO.read(Filepath("./src/RescriptREPL.res"))
    let x = separateOpenModulesFromRemainingCode(codeStr)

    if Js.String.length(x["openModulesSection"]) > 0 {
        let xs = [x["openModulesSection"], `open ${moduleName}`]
        let nextCodeStr = Js.Array.joinWith("\n", xs) ++ "\n" ++ x["remainingStr"]
        
        handleLoadModuleBuildAndEval(nextCodeStr, module(FO), module(RB), module(EvalJS))
        -> Promise.then(_result => {
            Promise.make((resolve, _reject) => resolve(. ()))
        })
    } else {
        let nextCodeStr = `open ${moduleName}` ++ "\n" ++ codeStr

        handleLoadModuleBuildAndEval(nextCodeStr, module(FO), module(RB), module(EvalJS))
        -> Promise.then(_result => {
            Promise.make((resolve, _reject) => resolve(. ()))
        })
    }
}

// Coupled with the regex error earlier, this one is also mystifying
// > Js.Array.joinWith("\n", xs)->Js.log
// ERROR running JavaScript code: Command failed: node ./src/evalJsCode.js
// undefined:12
// console.log(Js_array.joinWith("
//                               ^

// SyntaxError: Invalid or unexpected token
//     at Object.<anonymous> (C:\Users\jgood\Desktop\dev\rescript-repl\src\evalJsCode.js:1:1)
//     at Module._compile (node:internal/modules/cjs/loader:1254:14)
//     at Module._extensions..js (node:internal/modules/cjs/loader:1308:10)
//     at Module.load (node:internal/modules/cjs/loader:1117:32)
//     at Module._load (node:internal/modules/cjs/loader:958:12)
//     at Function.executeUserEntryPoint [as runMain] (node:internal/modules/run_main:81:12)
//     at node:internal/main/run_main_module:23:47

// Node.js v18.14.2

// stdout: 
// ''

// And again, the generated javascript is correct  (checked against rescript playground)
// var xs = ["1", "2","3"];
// console.log(Js_array.joinWith("\n", xs));