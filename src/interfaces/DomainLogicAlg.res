type cont_or_close = Continue | Close

module type DomainLogicAlg = {
    // parser will come in handy here...
    let handleUserInput : string => Promise.t<cont_or_close> // ()
    // any way to make this optional?
    let cleanup : () => ()
}