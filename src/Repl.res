// const repl = require("node:repl")

// @module("fs") external writeFileSync: string => string => () = "writeFileSync"
type replOptions<'a, 'b, 'c> = { 
    prompt: string,
    // Don't care about types 'b and 'c, but 'a should be any arbitrary type such that the repl will
    // display the result the same as a Node REPL does.
    eval: 'a => 'b => 'c => ((unit, 'a) => unit) => Promise.t<unit>
}
type command = string

type t

module Repl = {
    @send
    external defineCommand: (t, command, @uncurry ('a => unit)) => unit = "defineCommand"
    @send
    external displayPrompt: t => unit = "displayPrompt"
    @send
    external on: t => string => (unit => unit) => unit = "on"
}

@module("node:repl") external start: replOptions<'a, 'b, 'c> => t = "start"

// type multiLineMode = { active: bool, rescriptCodeInput: option<string> }
let multilineModeState = ref({ "active": false, "rescriptCodeInput": None })

let isRecoverableError = error => {
    let err = NodeJs.Errors.Error.toJsExn(error)
    if (Js.Exn.name(err)->Belt.Option.getUnsafe === "SyntaxError") {
        let re = %re("/^(Unexpected end of input|Unexpected token)/g")
        Js.Re.test_(re, Js.Exn.message(err)->Belt.Option.getUnsafe)
    } else {
        false
    }
}

// let f = () => {
//     Js.log("line 1")
//     Js.log("line 2")
// }

// let s = ref("")

// There's no state on the context which would indicate what current line of a multiline pasted input is currently
// being processed. 
// let eval = async (codeStr, context, filename, callback) => {
//    try {
//         // This is largely just the handleRescriptCodeCase function, but I moved it in here due to not having made the multilineMode yet.
//         // Probably will refactor this so that it's at least more testable...
//         // if multilineModeState.contents["active"] {
//         //     switch multilineModeState.contents["rescriptCodeInput"] {
//         //         | Some(prevCodeStr) => {
//         //             multilineModeState := {{ "active": true, "rescriptCodeInput": Some(prevCodeStr ++ "\n" ++ codeStr) }}
//         //             callback((), "") // repl will hang if this isn't invoked, and ideally would like to invoke this with unit, but the type needs to be fixed to string within this scope.
//         //         }
//         //         | None => Js.log("INVARIANT VIOLATION: The RescriptCode case expects for there to be some rescriptCodeInput present.")
//         //     }
//         // } else {
//         //     let rescriptStdout = await REPLLogic.handleBuildAndEval(codeStr, module(REPLLogic.FileOperations), module(REPLLogic.RescriptBuild), module(REPLLogic.EvalJavaScriptCode))
//         //     switch rescriptStdout {
//         //         | Some(s) => callback((), s)
//         //         | _ => callback((), "")
//         //     }
//         // }
//         // Js.log("codeStr in eval")
//         // Js.log(codeStr)
//         s := s.contents ++ "\n" ++ codeStr
//         Js.log("s")
//         Js.log(s)
//    } catch {
//         | e => {
//             if (isRecoverableError(e)) {
//                 Js.log("it's recoverable?")
//                 // callback(new repl.Recoverable(e));
//                 callback((), "")
//             }
//         }
//    }
// }

// let x = "{\n'first':'John',\n'last':'Jingleheimer',\n'address':{'street':'STREET','zip':85923}\n}"
// let y = x.split(" ").map(s => re.test(s) ? `'${s.split(":")[0]}':` : s)
// y => ["{\n'first':'John',\n'last':'Jingleheimer',\n'address':{'street':'STREET','zip':85923}\n}"]
// let z = y.map(s => s.split("\n"))
// z => ['{', "'first':'John',", "'last':'Jingleheimer',", "'address':{'street':'STREET','zip':85923}", '}']
// let transformed = Array.prototype.concat(...z).join("")
// transformed => "{'first':'John','last':'Jingleheimer','address':{'street':'STREET','zip':85923}}"
// transformed.replaceAll("'", "\"") => '{"first":"John","last":"Jingleheimer","address":{"street":"STREET","zip":85923}}'

// JSON.parse(transformed.replaceAll("'", "\""))
// {first: 'John', last: 'Jingleheimer', address: {…}}

// input:
// "{\n  first: 'John',\n  last: 'Jingleheimer',\n  address: { street: 'STREET', zip: 85923 }\n}"
// output:
// {first: 'John', last: 'Jingleheimer', address: {…}}
// address:  {street: 'STREET', zip: 85923}
// first: "John"
// last: "Jingleheimer"
// let convertToJSONString = rescriptStdoutStr => {
//   const re = /[a-z]*:/g
//   let y = rescriptStdoutStr.split(" ").map(s => re.test(s) ? `'${s.split(":")[0]}':` : s)
//   // let xs = rescriptStdoutStr.split(" ").map(s => re.test(s) ? `'${s.split(":")[0]}':` : s).map(s => s.split("\n"))
//   let z = y.map(s => s.split("\n"))
//   let transformed = Array.prototype.concat(...z).join("")
//   return JSON.parse(transformed.replaceAll("'", "\""))
// }

let convertToJSONString = %raw(`
    function(rescriptStdoutStr) {
        const re = /[a-z]*:/g
        let y = rescriptStdoutStr.split(" ").map(s => re.test(s) ? ["\"", s.split(":")[0], "\"", ":"].join("") : s)
        let z = y.map(s => s.split("\n"))
        let transformed = Array.prototype.concat(...z).join("")
        return JSON.parse(transformed.replaceAll("'", "\"").replaceAll("undefined", "\"None\""))
    }
`)

// PS C:rescript-repl> resrepl
// > type address = { "street": string, "zip": int }
// ''
// > type person = { "first": string, "last": string, "address": address }
// ''
// > let p = { "first": "John", "last": "Jingleheimer", "address": { "street": "STREET", "zip": 85923 } }
// Js.log''
// > Js.log(Some(p))
// {
//   first: 'John',
//   last: 'Jingleheimer',
//   address: { street: 'STREET', zip: 85923 }
// }
let handleDirtyWork = %raw(`
  function(callback, value) {
    if (value !== "") {
        try {
            callback(null, JSON.parse(value))
        } catch {
            // Okay... so objects are ending up here as such:
            // '{\n' +
            //     "  first: 'John',\n" +
            //     "  last: 'Jingleheimer',\n" +
            //     "  address: { street: 'STREET', zip: 85923 }\n" +
            //     '}'
            // But you want to have it in the format of a json string, so that
            // the results displayed at the REPL are just as Node repl would display it.
            // Need to wrap all series of characters which precede ":" in single quotes
            // to accomplish this.

            // Create a Regex which gets any series of characters A-Z/a-z not
            // surrounded by single quotes.


            try {
                // This this fails to parse stdout result of None
                callback(null, convertToJSONString(value))
            }  catch {
                console.log(value)
                callback(null, "couldnt parse None")
            }
        }
    } else {
        callback(null, value)
    }
  }
`)

let eval = async (codeStr, context, filename, callback) => {
    // This is largely just the handleRescriptCodeCase function, but I moved it in here due to not having made the multilineMode yet.
    // Probably will refactor this so that it's at least more testable...
    if multilineModeState.contents["active"] {
        switch multilineModeState.contents["rescriptCodeInput"] {
            | Some(prevCodeStr) => {
                multilineModeState := {{ "active": true, "rescriptCodeInput": Some(prevCodeStr ++ "\n" ++ codeStr) }}
                callback((), "") // repl will hang if this isn't invoked, and ideally would like to invoke this with unit, but the type needs to be fixed to string within this scope.
            }
            | None => Js.log("INVARIANT VIOLATION: The RescriptCode case expects for there to be some rescriptCodeInput present.")
        }
    } else {
        let rescriptStdout = await REPLLogic.handleBuildAndEval(codeStr, module(REPLLogic.FileOperations), module(REPLLogic.RescriptBuild), module(REPLLogic.EvalJavaScriptCode))
        switch rescriptStdout {
            // Attempting to invoke the callback in these branches with two different types results in a compilation error,
            // which is why we use Javascript to circumvent that.
            // This is necessary so that the result logged via Rescript's stdout after build and eval
            // will be displayed in the repl just the same as Node's REPL output for JS.
            // So instead of this:
            // > Js.log(x + 200)
            // '300'
            // We get this (for any arbitrary value provided from stdout):
            // > Js.log(x + 200)
            // 300
            | Some(s) => handleDirtyWork(callback, s) // callback((), s)
            | _ => handleDirtyWork(callback, "") // callback((), "")
        }
    }
}

let endMultiLineMode = async (replServer) => {
  let codeStr = multilineModeState.contents["rescriptCodeInput"]
  let rescriptStdout = await REPLLogic.handleBuildAndEval(codeStr->Belt.Option.getUnsafe, module(REPLLogic.FileOperations), module(REPLLogic.RescriptBuild), module(REPLLogic.EvalJavaScriptCode))
  multilineModeState := {{ "active": false, "rescriptCodeInput": None }}

  switch rescriptStdout {
        | Some(s) => Js.log(s)
        | _ => Js.log("")
    }

  Repl.displayPrompt(replServer);
}

// This was deleted while merging to main branch?
let startMultiLineMode = replServer => () => {
    multilineModeState := {{ "active": true, "rescriptCodeInput": Some("") }}
    Repl.displayPrompt(replServer)
}

let loadModule = replServer => (moduleName) => {
  REPLLogic.handleLoadModuleCase(moduleName, module(REPLLogic.FileOperations), module(REPLLogic.RescriptBuild), module(REPLLogic.EvalJavaScriptCode))->ignore
  Repl.displayPrompt(replServer);
}

let reset = replServer => (module(FO: REPLLogic.FileOperations)) => () => {
  FO.write(Filepath("./src/RescriptREPL.res"), "")
  Repl.displayPrompt(replServer);
}

let run_repl = () => {
    Js.log("Welcome to ReScript REPL\n")
    Js.log("Available Commands:")
    Js.log(".load   - Load a Module into the current REPL context")
    Js.log(".reset  - To clear ReScript code saved in the current REPL context")
    Js.log(".{:     - Start Mutliline Mode")
    Js.log(".}:     - End Mutliline Mode")

    let replServer = start({ prompt: "> ", eval })
    Repl.defineCommand(replServer, ":{", startMultiLineMode(replServer));
    Repl.defineCommand(replServer, "}:", () => {
        endMultiLineMode(replServer)->ignore
    });
    Repl.defineCommand(replServer, "load", loadModule(replServer));
    Repl.defineCommand(replServer, "reset", reset(replServer, module(REPLLogic.FileOperations)));

    Repl.on(replServer, "exit", () => {
        Js.log("exiting")
        try {
            NodeJs.Fs.unlinkSync("./src/RescriptRepl.res")
            NodeJs.Fs.unlinkSync("./src/RescriptRepl.bs.js")
            NodeJs.Fs.unlinkSync("./src/evalJsCode.js")
            ()
        } catch {
            | _ => ()
        }
    })
}

// For pasting code
// https://nodejs.org/api/repl.html#recoverable-errors

// Node is saving to a file for the Repl as well
// By default, the Node.js REPL will persist history between node REPL sessions by saving inputs to a .node_repl_history file located in the user's home directory.
// This can be disabled by setting the environment variable NODE_REPL_HISTORY=''
// https://nodejs.org/api/repl.html#environment-variable-options