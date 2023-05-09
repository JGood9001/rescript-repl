open Parser
open REPLCommands
open Utils

// λ> matchStr(":{", ":{and the rest of the string")->Js.log
// λ> true
let matchStr = (stringToMatch: string, inputStr: string) =>
    Js.String.slice(~from=0, ~to_=Js.String.length(stringToMatch), inputStr) == stringToMatch

// There's also string to char
// String.make(1, 'a') => "a"
// λ> charToString('a')->Js.log
// λ> a
let charToString = (c: char): string => String.make(1, c)

let char = (c: char): parser<string> =>
    Parser({ runParser: s => {
        let (x, remainingStr) = splitAt(s, 1)
        (x == charToString(c)) ? Some((remainingStr, x)) : None
    }})

// let pattern = "run"
// let s = "running"
// λ> Js.String.slice(~from=0, ~to_=Js.String.length(pattern), s)->Js.log
// λ> run
// Js.String.slice(~from=Js.String.length(pattern), ~to_=Js.String.length(s), s)->Js.log
// λ> ning
let str = (pattern: string): parser<string> =>
    Parser({ runParser: s => {
        let (x, remainingStr) = splitAt(s, Js.String.length(pattern))
        matchStr(pattern, s) ? Some((remainingStr, x)) : None
    }})

let space: parser<string> =
    Parser({ runParser: s => {
        let (x, remainingStr) = splitAt(s, 1)
        (" " == x) ? Some((remainingStr, x)) : None
    }})

let empty: parser<string> =
    Parser({ runParser: s => {
        ("" == s) ? Some((s, s)) : None
    }})


let rec collectUntil = (s: string, pattern: string): option<(string, string)> => {
    let (x, remainingStr) = splitAt(s, 1)
    x == pattern ? Some((x, remainingStr)) : contCollectUntil(x, remainingStr, pattern)
} and contCollectUntil = (collected: string, s: string, pattern: string) => {
    if Js.String.length(s) == 0 {
        None 
    } else {
        let (x, remainingStr) = splitAt(s, 1)
        x == pattern ? Some((x ++ remainingStr, collected)) : contCollectUntil(collected ++ x, remainingStr, pattern)
    }
}

let takeUntil = (pattern: string): parser<string> =>
    Parser({ runParser: s => {
        switch collectUntil(s, pattern) {
            | Some((remaining_str, matched_str)) => Some((remaining_str, matched_str))
            | None => None
        }
    }})

let rescriptFileP: parser<(string, string)> =
    ((filename, ext) => (filename, ext))
    ->ParserApplicative.fmap(takeUntil("."))
    ->ParserApplicative.apply(str(".res"))

let loadCommandP: parser<replCommand> = {
    ((_, _, (filename, ext)) => LoadModule(filename ++ ext))
    ->ParserApplicative.fmap(str(":load"))
    ->ParserApplicative.apply(space)
    ->ParserApplicative.apply(rescriptFileP)
    // ->ParserApplicative.apply(takeUntil("."))
    // ->ParserApplicative.apply(str(".res"))
}

let startMultiLineCommandP: parser<replCommand> =
    ((_, _) => StartMultiLineMode)->ParserApplicative.fmap(str(":{"))->ParserApplicative.apply(empty)

let endMultiLineCommandP: parser<replCommand> =
    ((_, _) => EndMultiLineMode)->ParserApplicative.fmap(str("}:"))->ParserApplicative.apply(empty)

let rescriptCodeStartsWithJsLogP: parser<string> =
    (x => x)->ParserApplicative.fmap(str("Js.log"))

// Ahhh... for these "ends with" parsers
// you need the some function on applicative.
// ^^ TODO/LLO:
// Implement this, as it's what is currently breaking the REPL flow for what I implemented in REPLLogic.res
let rescriptCodeEndsWithJsLogP: parser<string> =
    ((x, _) => x)->ParserApplicative.fmap(ParserAlternative.some(str("->Js.log")))->ParserApplicative.apply(empty)

let rescriptCodeStartsOrEndsWithJsLogP: parser<string> =
    ParserAlternative.alternative(rescriptCodeStartsWithJsLogP, rescriptCodeEndsWithJsLogP) // compose(string("->Js.log"), empty))

let rescriptFileP: parser<string> =
    ((x, _) => x)->ParserApplicative.fmap(ParserAlternative.some(str(".res")))->ParserApplicative.apply(empty)

let javascriptFileP: parser<string> =
    ((x, _) => x)->ParserApplicative.fmap(ParserAlternative.some(str(".bs.js")))->ParserApplicative.apply(empty)

let rescriptJavascriptFileP =
    ParserAlternative.alternative(rescriptFileP, javascriptFileP)