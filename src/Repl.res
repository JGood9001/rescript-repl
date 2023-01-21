// https://forum.rescript-lang.org/t/js-api-to-compile-rescript-to-js/869/7
// https://github.com/rescript-lang/rescript-compiler/pull/4518

// https://forum.rescript-lang.org/t/node-js-official-bindings/2193/10?u=jamesg
// https://www.npmjs.com/package/rescript-nodejs
// https://github.com/TheSpyder/rescript-nodejs/blob/main/src/Process.res#L143
// https://github.com/TheSpyder/rescript-nodejs/blob/main/src/Readline.res#L57

open NodeJs

let rl = Readline.make(
     Readline.interfaceOptions(~input=Process.process->Process.stdin, ~output=Process.process->Process.stdout, ()),
)

let prompt = query =>
    Promise.make((resolve, _reject) => rl->Readline.Interface.question(query, x => resolve(. x)))

let rec repl = () => {
    prompt("\u03BB> ") -> Promise.then(user_input => {
        Js.log("User entered:")
        Js.log(user_input)

        // :load
        if user_input == ":exit" {
            rl->Readline.Interface.close
        } else {
            // TODO: Handle writing to file and eval stuff here
            repl()
        }
        
        Promise.resolve(user_input)
    }) -> ignore
}