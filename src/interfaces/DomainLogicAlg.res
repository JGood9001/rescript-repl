type multiLineMode = {
        active: bool,
        rescriptCodeInput: option<string>,
    }

type domainLogicState = {
    multilineMode: multiLineMode
}

type contOrClose<'a> = Continue('a) | Close

module type DomainLogicAlg = {
    type t

    let make : () => t
    let handleUserInput : t => string => Promise.t<contOrClose<t>>
    let start_repl : (t => Promise.t<contOrClose<t>>) => (() => ()) => Promise.t<contOrClose<t>>
    // any way to make this optional?
    let cleanup : () => ()
}