open CommandLineIOAlg
open DomainLogicAlg

// let handleContOrClose = (contOrClose, cont, close) => { //: Promise.t<cont_or_close<DomainLogicAlg.state<DomainLogicAlg.t>>> => {
//     Promise.make((resolve, _reject) => {
//         switch contOrClose {
//             | Continue(s) => { // : DomainLogicAlg.state<DomainLogicAlg.t>
//                 cont(s)->Promise.then(_ => Promise.make((res, _rej) => res(. ())))->ignore // the Promise.then becomes necessary because the recursive function is async... now
//                 resolve(. contOrClose)
//             }
//             | Close => {
//                 Js.log("See you Space Cowboy")
//                 close()
//                 resolve(. contOrClose)
//             }
//         }
//     })
// }

// LLO
// DOn't think it's ideal to have to specify type t here for DL, so I should instead create more functions on DL which handle the repl loop flow
// In a start_repl function...
// let repl = async (module (CLIO : CommandLineIOAlg), module (DL : DomainLogicAlg with type t = DomainLogicAlg.domain_logic_state)) => {
//     let cliInterface = CLIO.on(CLIO.make(), "close", DL.cleanup)
//     let close = () => CLIO.close(cliInterface)
//     // : DomainLogicAlg.state<DomainLogicAlg.t>
//     let prompt = async (s) => await CLIO.prompt(cliInterface, "\u03BB> ", DL.handleUserInput(s))

//     let state = DL.make()

//     // If you add that type t to DomainLogicAlg, then creating it and passing it through the recursive
//     // invocations of run_loop will be necessary to maintain the running state.
//     // : DomainLogicAlg.state<DomainLogicAlg.t>
//     let rec run_loop = async (s) => {
//         let contOrClose = await prompt(s)
//         await handleContOrClose(contOrClose, run_loop, close)
//     }

//     await run_loop(state)
// }

let repl = async (module (CLIO : CommandLineIOAlg), module (DL : DomainLogicAlg)) => {
    let cliInterface = CLIO.on(CLIO.make(), "close", DL.cleanup)
    let close = () => CLIO.close(cliInterface)
    let prompt = async (s) => await CLIO.prompt(cliInterface, "\u03BB> ", DL.handleUserInput(s))
    (await DL.start_repl(prompt, close))->ignore
    Promise.make((resolve, _reject) => resolve(. ()))
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