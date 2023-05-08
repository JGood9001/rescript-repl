type multiline_mode_state = {
        active: bool,
        rescipe_code_input: option<string>,
    }

type domain_logic_state = {
        multiline_mode: multiline_mode_state,
        prev_file_contents_state: option<string>, // actually... perhaps this piece of state wasn't necessary
    }

// type state<'a> = State('a)

// type cont_or_close<'a> = Continue(state<'a>) | Close
type cont_or_close<'a> = Continue('a) | Close

module type DomainLogicAlg = {
    type t

    let make : () => t
    let handleUserInput : t => string => Promise.t<cont_or_close<t>>
    let start_repl : (t => Promise.t<cont_or_close<t>>) => (() => ()) => Promise.t<cont_or_close<t>>
    // any way to make this optional?
    let cleanup : () => ()
}