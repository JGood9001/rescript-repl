open CommandLineIOAlg
open DomainLogicAlg

let repl = (module (CLIO : CommandLineIOAlg), module (DL : DomainLogicAlg)) => {
    let cliInterface = CLIO.on(CLIO.make(), "close", DL.cleanup)
    
    let rec start = () => {
        CLIO.prompt(cliInterface, "\u03BB> ", DL.handleUserInput)
        ->Promise.then(cont_or_close => {
            Promise.make(
                (resolve, _reject) => {
                    switch cont_or_close {
                        | Continue => {
                            cont()
                            resolve(. cont_or_close)
                        }
                        | Close => {
                            Js.log("See you Space Cowboy")
                            CLIO.close(cliInterface)
                            resolve(. cont_or_close)
                        }
                    }
                }
            ) // End Promise.make
        }) // End Promise.then
        -> ignore
    } and cont = () => {
        CLIO.prompt(cliInterface, "\u03BB> ", DL.handleUserInput)
        ->Promise.then(cont_or_close => {
            Promise.make(
                (resolve, _reject) => {
                    switch cont_or_close {
                        | Continue => {
                            cont()
                            resolve(. cont_or_close)
                        }
                        | Close => {
                            Js.log("See you Space Cowboy")
                            CLIO.close(cliInterface)
                            resolve(. cont_or_close)
                        }
                    }
                }
            ) // End Promise.make
        }) // End Promise.then
        -> ignore
    }

    start()
}

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