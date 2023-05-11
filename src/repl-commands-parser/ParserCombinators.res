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

// input = "Utils not_valid_module_str"
// output = (" not_valid_module_str", "Utils")
let takeWhile = (s: string, xs: array<string>) => {
    let (idx, matchedStr) =
        Js.String.split("", s)->Js.Array2.reduce(((idx, s2), char) => {
            // Js.Array2.includes(["a", "b", "c"], "b") == true
            if Belt.Option.isSome(s2) && Js.Array2.includes(xs, char) {
                (idx + 1, Belt.Option.map(s2, x => x ++ char))
            } else {
                (idx, None)
            }
        }, (0, Some("")))

    switch matchedStr {
        | Some(x) => {
            let (_, remainingStr) = splitAt(s, idx)
            (remainingStr, x)
        }
        | None => (s, "")
    }
}

let any = (pattern: array<string>): parser<string> =>
    Parser({ runParser: s => {
        let (remainingStr, matchedStr) = takeWhile(s, pattern)
        if remainingStr == s {
            None
        }  else {
            Some((remainingStr, matchedStr))
        }
    }})

let validModuleNameChars = [
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
]

let loadCommandP: parser<replCommand> = {
    ((_, _, moduleName, _) => LoadModule(moduleName))
    ->ParserApplicative.fmap(str(":load"))
    ->ParserApplicative.apply(space)
    ->ParserApplicative.apply(any(validModuleNameChars))
    ->ParserApplicative.apply(empty)
}

let startMultiLineCommandP: parser<replCommand> =
    ((_, _) => StartMultiLineMode)->ParserApplicative.fmap(str(":{"))->ParserApplicative.apply(empty)

let endMultiLineCommandP: parser<replCommand> =
    ((_, _) => EndMultiLineMode)->ParserApplicative.fmap(str("}:"))->ParserApplicative.apply(empty)

let resetCommandP: parser<replCommand> =
    ((_, _) => Reset)->ParserApplicative.fmap(str(":reset"))->ParserApplicative.apply(empty)


let rescriptCodeStartsWithJsLogP: parser<string> =
    (x => x)->ParserApplicative.fmap(str("Js.log"))

// Ahhh... for these "ends with" parsers
// you need the some function on applicative.
// ^^ TODO/LLO:
// Implement this, as it's what is currently breaking the REPL flow for what I implemented in REPLLogic.res
let rescriptCodeEndsWithJsLogP: parser<string> =
    ((x, _) => x[0])->ParserApplicative.fmap(ParserAlternative.some(str("->Js.log")))->ParserApplicative.apply(empty)

let rescriptCodeStartsOrEndsWithJsLogP: parser<string> =
    ParserAlternative.alternative(rescriptCodeStartsWithJsLogP, rescriptCodeEndsWithJsLogP)

let rescriptFileP: parser<string> =
    ((x, _) => x[0])->ParserApplicative.fmap(ParserAlternative.some(str(".res")))->ParserApplicative.apply(empty)

let javascriptFileP: parser<string> =
    ((x, _) => x[0])->ParserApplicative.fmap(ParserAlternative.some(str(".bs.js")))->ParserApplicative.apply(empty)

let rescriptJavascriptFileP =
    ParserAlternative.alternative(rescriptFileP, javascriptFileP)

let openModuleLineP =
    ((openStr, _space, moduleName) => openStr ++ " " ++ moduleName ++ "\n")
    ->ParserApplicative.fmap(str("open")) 
    ->ParserApplicative.apply(space)
    ->ParserApplicative.apply(takeUntil("\n"))

// Going to need to implement Alternative.many, as you'll want to retrieve all lines that start with open
let openModuleLinesP =
    ParserAlternative.some(openModuleLineP)

type openModuleSection = OpenModuleSection(string)

let openModuleSectionP: parser<openModuleSection> =
    ((openModuleLines) => OpenModuleSection(Belt.Array.reduce(openModuleLines, "", (a, b) => a ++ b)))
    ->ParserApplicative.fmap(openModuleLinesP)
