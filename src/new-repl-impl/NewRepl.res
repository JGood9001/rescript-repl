open CommandLineIOAlg
open DomainLogicAlg

let handle_cont_or_close = (cont_or_close, cont, close): Promise.t<cont_or_close> => {
    Promise.make((resolve, _reject) => {
        switch cont_or_close {
            | Continue => {
                cont()->Promise.then(_ => Promise.make((res, _rej) => res(. ())))->ignore // the Promise.then becomes necessary because the recursive function is async... now
                resolve(. cont_or_close)
            }
            | Close => {
                Js.log("See you Space Cowboy")
                close()
                resolve(. cont_or_close)
            }
        }
    })
}

let repl = async (module (CLIO : CommandLineIOAlg), module (DL : DomainLogicAlg)) => {
    let cliInterface = CLIO.on(CLIO.make(), "close", DL.cleanup)
    let close = () => CLIO.close(cliInterface)
    let prompt = async () => await CLIO.prompt(cliInterface, "\u03BB> ", DL.handleUserInput) 

    let rec run_loop: () => Promise.t<cont_or_close> = async () => {
        let cont_or_close = await prompt()
        await handle_cont_or_close(cont_or_close, run_loop, close)
    }

    await run_loop()
}

// before switching to async await:
// let repl = (module (CLIO : CommandLineIOAlg), module (DL : DomainLogicAlg)) => {
//     let cliInterface = CLIO.on(CLIO.make(), "close", DL.cleanup)
//     let close = () => CLIO.close(cliInterface)

//     let rec run_loop = () => {
//          CLIO.prompt(cliInterface, "\u03BB> ", DL.handleUserInput)
//         ->Promise.then(cont_or_close => handle_cont_or_close(cont_or_close, run_loop, close))
//         -> ignore
//     }

//     run_loop()
// }

//     // All right... now due to DomainLogicAlg (the implementation specific to rescript repl) needing to handle file operations
//     // I really don't know how to go about implementing it such that there would be instances for both prod/test.
//     // Well after thinking about it a little more, the handle_get_next_contents and (prev_contents/nexdt_contents stuff is domain specific)
//     // and shouldn't be a concern to the repl function.
//     // Maintaining that within the DomainLogicAlg would imply some kind of mutable state if I'm not going to pass it explicitly
//     // through the recursive invocations (ahhh, but I don't even need to recurse, this can just be a loop now).
//     // Ultimately, the implementation of DomainLogicAlg will need to include FilesAlg for which a prod/test instance of that
//     // may be provided.
    
//     // TODO: Allow user to provide config file for prompt cursor/exit msg
//     Js.log("See you Space Cowboy")
// }