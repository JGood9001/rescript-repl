open CommandLineIOAlg
open DomainLogicAlg

let repl = async (module (CLIO : CommandLineIOAlg), module (DL : DomainLogicAlg)) => {
    let cliInterface = CLIO.on(CLIO.make(), "close", DL.cleanup)
    let close = () => CLIO.close(cliInterface)
    let prompt = async (s) => await CLIO.prompt(cliInterface, "\u03BB> ", DL.handleUserInput(s))
    (await DL.start_repl(prompt, close))->ignore
    Promise.make((resolve, _reject) => resolve(. ()))
}