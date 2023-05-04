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

// May 4th FIX:
// - If ./src/RescriptRepl.res | ./src/RescriptRepl.bs.js don't exist when "close" event is received,
//   then don't attempt to remove them... prints out a node error to the user if you do.

// Need to see if I can create an interface which wraps Readline (so I can supply a test instance)
// https://github.com/TheSpyder/rescript-nodejs/blob/main/src/Readline.res
// https://nodejs.org/api/readline.html#class-interfaceconstructor
// https://github.com/TheSpyder/rescript-nodejs/blob/main/src/Readline.res#L57
// Every instance is associated with a single input Readable stream and a single output Writable stream.
// The output stream is used to print prompts for user input that arrives on, and is read from, the input stream.
// ^^ So the test implementation will need to emulate this.
let rl = Readline.make(
    Readline.interfaceOptions(~input=Process.process->Process.stdin, ~output=Process.process->Process.stdout, ()),
)

// The general flow (not specific to my particular use case):
// 1. Create a ReadLine instance which facilitates receiving from stdin and sending output back to the user via stdout (Readline.make and Readline.interfaceOptions)
// 2. 
// Finally, Clean up upon "close" event being initiated via Ctrl+D | Ctrl+C sent by the user

// The interface to the repl (specific to this domain) logic:
// 

// ^^ I imagine both of these being passed to the repl function (as first class modules implementing an algebra)

// 1. CommandLineIO
// 2. Logic

// let e1 = (module (E : ExpAlg with type t = eval)) =>
	// E.add(E.lit(1), E.lit(2))

// So the user can provide Readline.Interface.t, as you want to keep the underlying implementation hidden from the logic that handles the sequencing
// of the commandlineioalg and domainlogicalg function invocations.
type commandLineIO<'a> = 'a

// well Readline.make returns a Interface.t
module type CommandLineIOAlg = {
    type t

    let make : () => t
    let prompt : t => string => (string => ()) => unit
    let close : t => unit
}

module type DomainLogicAlg = {
    // parser will come in handy here...
    let handleUserInput : string => ()
    // any way to make this optional?
    let cleanup : () => unit
}

// will be used when creating the prod instance for CommandLineIOAlg
let prompt_2 = (rl, query, cb) =>
    Promise.make((resolve, _reject) => rl->Readline.Interface.question(query, x => resolve(. x)))
    ->Promise.then(user_input => cb(user_input))
    ->ignore


let rec repl_2 = (module (CLIO : CommandLineIOAlg), module (DL : DomainLogicAlg)) => {
    // 1. Create instance of commandline
    let cliInterface = CLIO.make()
    // 2. Setup cleanup function upon cliInterface receiving the "close" event
    // Will require invoking the passed in function whenever... (need to implement the getting input from the user first)
    // invoke domainlogicalg's cleanup implementation + set mutable variable to indicate that repl's while loop should be broken out of.
    // rl
    // ->Readline.Interface.on(Event.fromString("close"), () => {
    // Js.log("See You Space Cowboy")
    // // remove files
    // unlinkSync("./src/RescriptRepl.res")
    // unlinkSync("./src/RescriptRepl.bs.js")
    // }) -> ignore
    // For the test instance, this would require that the type t is mutable so that event handlers may be stored...
    // cliInterface.on("close", () => {
    //   DL.cleanup()
    //   Js.log("See you Space Cowboy")    
    // })

    // Getting input from the user...
    // prompt("\u03BB> ") -> Promise.then(user_input => {
    // Can I hide the fact that promises are being used here?
    // where prompt currently is:
    // let prompt = query => Promise.make((resolve, _reject) => rl->Readline.Interface.question(query, x => resolve(. x)))
    // I suppose just moving the Promise.then into the prompt function and having repl provide a callback function to prompt will work.
    // while loop here
    CLIO.prompt(cliInterface, "\u03BB> ", DL.handleUserInput)
    // handleUserInput actually also needs access to cliInterface's close function,
    // as that's what I was doing below in the first implementation :exit => rl->Readline.Interface.close
    // All right... now due to DomainLogicAlg (the implementation specific to rescript repl) needing to handle file operations
    // I really don't know how to go about implementing it such that there would be instances for both prod/test.
    // Well after thinking about it a little more, the handle_get_next_contents and (prev_contents/nexdt_contents stuff is domain specific)
    // and shouldn't be a concern to the repl function.
    // Maintaining that within the DomainLogicAlg would imply some kind of mutable state if I'm not going to pass it explicitly
    // through the recursive invocations (ahhh, but I don't even need to recurse, this can just be a loop now).
    // Ultimately, the implementation of DomainLogicAlg will need to include FilesAlg for which a prod/test instance of that
    // may be provided.

}

// Rescript REPL Domain specific logic (to be used within handleUserInput)...
// 1. save
// 2. write
// 3. rollback
// 4. unlinkSync (which is NodeJS' delete file essentially...)
// 5. rewrite (implemented in terms of delete and write) replacing contents of a current file with a provided string

// ^^ Refactoring ideation...

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
  // remove files
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
