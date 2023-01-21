// https://forum.rescript-lang.org/t/js-api-to-compile-rescript-to-js/869/7
// https://github.com/rescript-lang/rescript-compiler/pull/4518

// https://forum.rescript-lang.org/t/node-js-official-bindings/2193/10?u=jamesg
// https://www.npmjs.com/package/rescript-nodejs
// https://github.com/TheSpyder/rescript-nodejs/blob/main/src/Process.res#L143
// https://github.com/TheSpyder/rescript-nodejs/blob/main/src/Readline.res#L57

// https://forum.rescript-lang.org/t/plans-to-provide-a-rescript-repl/525/5
open NodeJs

@module("fs") external readFileSync: string => string => string = "readFileSync"
@module("fs") external writeFileSync: string => string => () = "writeFileSync"
@module("fs") external writeFile: string => string => (string => ()) => () = "writeFile"
@module("fs") external unlinkSync: string => () = "unlinkSync"
external eval: string => () = "eval"
external setTimeout: (() => ()) => string => () = "setTimeout"

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

let write = (filename, contents) =>
    writeFileSync(filename, contents)
    // asyncrhonous writeFile is problematic when I want to reset the file contents
    // writeFile(filename, contents, err => {
    //             if !Js.isNullable(Js.Nullable.return(err)) {
    //                 Js.Exn.raiseError(err)
    //             }
    //             // file written successfully
    //         })

let rewrite = (filename, contents) => {
    unlinkSync(filename)
    write(filename, contents)
}

let handle_get_next_contents = s => {
    try {
        let contents = readFileSync("./src/RescriptRepl.res", "utf8")
        (contents, contents ++ "\n" ++ s)
    } catch {
        | Js.Exn.Error(_obj) => ("", s)
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
                    // Need to see if the compile error which caused the rescript
                    // to fail building can be displayed here...
                    | Some(msg) => {
                        Js.log("ERROR: " ++ msg)
                        // TODO: Will need to see if I can improve highlighting the error later, but for now
                        // this at least outputs whether the build succeeded/failed and will highlight the error
                        // that caused it within the RescriptRepl.res file.
                        Js.log("stdout: " ++ Buffer.toString(stdout))

                        // Rollback to last successful file build
                        write("./src/RescriptRepl.res", prev_contents) -> ignore
                    }
                    | None => ()
                }
            }) -> ignore
        } else {
            // Js.log("Finished building the RescriptRepl.bs.js file and invoking callback")
            f()
        }

        // if (stderr) {
        //     // Js.log(`stderr: ${stderr}`);
        //     Js.log("ERROR: " ++ stderr)
        // }
        // // Js.log(`stdout: ${stdout}`);

        // Js.log("stderr: " ++ Buffer.toString(stderr))
        
    })
}

// let build_rescript_code = (prev_contents, f) => {
//     let _x = ChildProcess.execSync("npm run res:build")
//     Js.log("Finished building the RescriptRepl.bs.js file and invoking callback")
//     f()
// }

let eval_js_code = () => {
    let contents = readFileSync("./src/RescriptRepl.bs.js", "utf8")
    eval(contents)
}

// λ> let filepath = "./src/add/Add.res"
// λ> Js.log(Js.String.split("/", filepath))
// λ> [ '.', 'src', 'add', 'Add.res' ]
// Js.log(Js.String.split("/", "/Add.res"))
// λ> [ '', 'Add.res' ]
let extract_module_name = (module_filepath) => {
    let xs = Js.String.split("/", module_filepath)
    let x = Js.String.split(".", xs[Belt.Array.length(xs) - 1])
    switch x {
        | [module_name, "res"] => Some(module_name)
        | _ => {
            Js.log("ERROR: expected a .res file, but received: " ++ Js.Array.joinWith(".", x))
            None
        }
    }
}

let create_module_str = (module_name, module_contents) =>
    "module " ++ module_name ++ " = { \n" ++ module_contents ++ "\n }"

// optional string to indicate previous state of multiline code block
let rec repl = (reset_contents) => {
    prompt("\u03BB> ") -> Promise.then(user_input => {
        // :load
        // :reset
        switch Js.String.split(" ", user_input) {
            // | ["```"] => Js.Exn.raiseError("IMPLEMENT MULTI LINE CODE BLOCKS")
            | [":exit"] => rl->Readline.Interface.close
            | [":load", module_filepath] => {
                // λ> :load ./src/add/Add.res
                // module_filepath: ./src/add/Add.res

                // Js.log("module_filepath: " ++ module_filepath)
                // let [module_name, _] = Js.String.split(".", module_filepath)
                switch extract_module_name(module_filepath) {
                    | Some(module_name) => {
                        try {
                            let module_contents = readFileSync(module_filepath, "utf8")
                            let module_str = create_module_str(module_name, module_contents)
                            let (prev_contents, next_contents) = handle_get_next_contents(module_str)

                            write("./src/RescriptRepl.res", next_contents) -> ignore
                            build_rescript_code(prev_contents, eval_js_code) -> ignore
                            repl(None)
                        } catch {
                            | Js.Exn.Error(obj) => {
                                Js.log(obj)
                                repl(None)
                            }
                        }
                    }
                    | None => repl(None)
                }
            }
            | [":reset"] => {
                rewrite("./src/RescriptRepl.res", "") -> ignore
                repl(None)
            }
            | _ => {
                let xs = Js.String.split("(", user_input)
                let x = xs[0]
                switch x {
                    | "Js.log" => {
                        switch reset_contents {
                            | Some(pc) => rewrite("./src/RescriptRepl.res", pc) -> ignore
                            | None => ()
                        }

                        let (prev_contents, next_contents) = handle_get_next_contents(user_input)
                        write("./src/RescriptRepl.res", next_contents) -> ignore
                        build_rescript_code(prev_contents, eval_js_code) -> ignore

                        // rollback the previous version without the log statement
                        // rewrite("./src/RescriptRepl.res", prev_contents) -> ignore
                        // ^^ rewriting here causes a weird issue where it overwrites the file being built
                        // so the log never happens, so I have to opt for passing the prev_contents as
                        // the argument for the next repl loop
                        repl(Some(prev_contents))
                    }
                    | _ => {
                         switch reset_contents {
                            | Some(pc) => rewrite("./src/RescriptRepl.res", pc) -> ignore
                            | None => ()
                        }

                        let (prev_contents, next_contents) = handle_get_next_contents(user_input)
                        write("./src/RescriptRepl.res", next_contents) -> ignore
                        build_rescript_code(prev_contents, eval_js_code) -> ignore
                        repl(None)
                    }
                }
            }
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

// λ> let x = ":exit"
// λ> let y = ":load Mod.res"
// λ> Js.log(Js.String.split(" ", y))
// λ> [ ':load', 'Mod.res' ]
// λ> Js.log(Js.String.split(" ", x))
// λ> [ ':load', 'Mod.res' ]
// [ ':exit' ]

// λ> :load Add.res
// module_filepath: Add.res
// λ> Js.log(Add.add(10, 12))
// λ> 22

// If the last line entered in the repl is Js.log...
// then don't append it to the file, just create a temporary string
// and eval it instead
// λ> Js.log(Js.String.split("/", filepath))
// λ> [Function (anonymous)]
// [ '.', 'src', 'add', 'Add.res' ]
// λ> Js.log(Js.String.split("/", "./src/Add.res"))
// λ> [Function (anonymous)]
// [ '.', 'src', 'add', 'Add.res' ]
// [ '.', 'src', 'Add.res' ]
// λ> Js.log(Js.String.split("/", "Add.res"))
// λ> [Function (anonymous)]
// [ '.', 'src', 'add', 'Add.res' ]
// [ '.', 'src', 'Add.res' ]
// [ 'Add.res' ]

// Also, should have a similar behavior to Js.log (where the expr typed in is evaluated
// and then removed from the file for the next repl loop)
// That way you don't have to explicitly Js.log it.
// For any lines that don't start with [ "let", "module", ?... ]
// λ> Js.log(Js.Array.joinWith(".", ["Add", "rs"]))
// λ> Add.rs
