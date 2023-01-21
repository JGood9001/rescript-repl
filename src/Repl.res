// https://forum.rescript-lang.org/t/js-api-to-compile-rescript-to-js/869/7
// https://github.com/rescript-lang/rescript-compiler/pull/4518

// https://forum.rescript-lang.org/t/node-js-official-bindings/2193/10?u=jamesg
// https://www.npmjs.com/package/rescript-nodejs
// https://github.com/TheSpyder/rescript-nodejs/blob/main/src/Process.res#L143
// https://github.com/TheSpyder/rescript-nodejs/blob/main/src/Readline.res#L57

// https://forum.rescript-lang.org/t/plans-to-provide-a-rescript-repl/525/5
open NodeJs

@module("fs") external readFileSync: string => string => string = "readFileSync"
@module("fs") external writeFile: string => string => (string => ()) => () = "writeFile"
@module("fs") external unlinkSync: string => () = "unlinkSync"
external eval: string => () = "eval"

let rl = Readline.make(
     Readline.interfaceOptions(~input=Process.process->Process.stdin, ~output=Process.process->Process.stdout, ()),
)

// https://github.com/TheSpyder/rescript-nodejs/blob/main/src/Readline.res#L38
// {
//     Readline.Interface.on(Readline.Events.close(rl, () => {
//         Js.log("CLEANING UP")
//         Process.process->Process.exit(())
//     }))

//     // Readline.Interface.on(rl, ())
//     ()
// }

rl
->Readline.Interface.on(Event.fromString("close"), () => {
  Js.log("See You Space Cowboy")
  unlinkSync("./src/RescriptRepl.res")
  unlinkSync("./src/RescriptRepl.bs.js")
}) -> ignore

let prompt = query =>
    Promise.make((resolve, _reject) => rl->Readline.Interface.question(query, x => resolve(. x)))

let handle_get_next_contents = s => {
    try {
        let contents = readFileSync("./src/RescriptRepl.res", "utf8")
        contents ++ "\n" ++ s
    } catch {
        | Js.Exn.Error(_obj) => s
    }
}

// https://github.com/TheSpyder/rescript-nodejs/blob/main/src/ChildProcess.res#L81
// external exec: (string, (Js.nullable<Js.Exn.t>, Buffer.t, Buffer.t) => unit) => t = "exec"
let build_rescript_code = (f) => {
    ChildProcess.exec("npm run res:build", (error, stdout, stderr) => {
        if (!Js.isNullable(error)) {
            // https://rescript-lang.org/docs/manual/latest/api/js/nullable#bind
            Js.Nullable.bind(error, (. error_str) => {
                switch error_str -> Js.Exn.message {
                    // Need to see if the compile error which caused the rescript
                    // to fail building can be displayed here...
                    | Some(msg) => Js.log("ERROR: " ++ msg)
                    | None => ()
                }
            }) -> ignore
        } else {
            // Js.log("Finished building the RescriptRepl.bs.js file")
            f()
        }


        // TODO: How to use the Buffer.t?
        // if (stderr) {
        //     // Js.log(`stderr: ${stderr}`);
        //     Js.log("ERROR: " ++ stderr)
        // }
        // // Js.log(`stdout: ${stdout}`);
        // Js.log("stdout: " ++ stdout)
    })
}

let eval_js_code = () => {
     let contents = readFileSync("./src/RescriptRepl.bs.js", "utf8")
     eval(contents)
}

let rec repl = () => {
    prompt("\u03BB> ") -> Promise.then(user_input => {
        // :load
        if user_input == ":exit" {
            rl->Readline.Interface.close
        } else {
            let next_contents = handle_get_next_contents(user_input)

            writeFile("./src/RescriptRepl.res", next_contents, err => {
                if !Js.isNullable(Js.Nullable.return(err)) {
                    Js.Exn.raiseError(err)
                }
                // file written successfully
            })

            build_rescript_code(eval_js_code) -> ignore
            // TODO
            // Will need to catch, display, handle
            // rolling back to the previous working RescriptREPL.res
            // file's content if any errors are encountered at this step.
            // eval_js_code() -> ignore

            repl()
        }
        
        Promise.resolve(user_input)
    }) -> ignore
}

// It works, but it would be ideal if the Js.log output didn't
// appear on the same line as the next prompt. 

// λ> let x = "Hello, "
// λ> let y = "ReScript REPL"
// λ> Js.log(x ++ y)
// λ> Hello, ReScript REPL
// See You Space Cowboy

// λ> let x = 9001
// λ> let y = 10
// λ> Js.log(x + y)
// λ> 9011
