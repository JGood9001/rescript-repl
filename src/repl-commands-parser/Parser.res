open Functor
open Applicative
open Alternative
open REPLCommands
open Utils

type parseResult<'a> = option<(string, 'a)>
type parser<'a> = Parser({ runParser: string => parseResult<'a> })

module ParserFunctor : (Functor with type t<'a> = parser<'a>) = {
    type t<'a> = parser<'a>
    let fmap = (f, Parser(p)) => {
        Parser({ runParser: s => {
            // run the provided parser, then run the function over the result returned from that parser.
            switch p.runParser(s) {
                | Some((remainingStr, result)) => Some((remainingStr, f(result)))
                | None => None
            }
        }})
    }
}

// Not possible to test these laws with the parser type
module TFP = TestFunctor(ParserFunctor)

// let Parser(apply_after_transform_p) = {
//     ParserApplicative.apply(
//         // expect this after the first step...
//         // [ ', and more', ("hi", comma) => Js.String.toUpperCase("hi") ++ comma ]
//         ParserApplicative.fmap((hi, comma) => Js.String.toUpperCase(hi) ++ comma, str("hi")),
//         str(",")
//     )
// }
// Js.log(apply_after_transform_p.runParser("hi, and more"))
module ParserApplicative : (Applicative with type t<'a> = parser<'a>) = {
    include ParserFunctor
    let pure = _p => Parser({ runParser: _ => None })
    let apply = (Parser(pf): t<('a => 'b)>, Parser(p): t<'a>): t<'b> =>
        Parser({ runParser: s => {
            switch pf.runParser(s) {
                | Some((remainingStr, f)) => {
                    switch p.runParser(remainingStr) {
                        | Some((remainingStr, result)) => Some((remainingStr, f(result)))
                        | None => None
                    }
                }
                | None => None
            }
        }})
}

// Not possible to test these laws with the parser type
module TAP = TestApplicative(ParserApplicative)

module ParserAlternative : (Alternative with type t<'a> = parser<'a>) = {
    include ParserApplicative
    let empty = Parser({ runParser: _ => None }) // pure(None)
    let alternative = (Parser(p1), Parser(p2)) => {
        Parser({
            runParser: s => {
                switch p1.runParser(s) {
                    | Some(remainingStr, result) => Some(remainingStr, result)
                    | None => {
                        switch p2.runParser(s) {
                            | Some(remainingStr, result) => Some(remainingStr, result)
                            | None => None
                        }
                    }
                }
            }
        })
    }
    let some = (Parser(p)) => {
        // repeatedly invoke parser with s
        // return first case where Some is yielded
        // and drop the first char from the string and retry if None is yielded
        let rec run = s => {
            if Js.String.length(s) == 0 {
                None
            } else {
                switch p.runParser(s) {
                    | Some(x) => Some(x)
                    | None => {
                        let (_, remainingStr) = splitAt(s, 1)
                        run(remainingStr)
                    }
                }
            }
        }

        Parser({ runParser: run })
    }
}

let runParser = (Parser(p), s: string) =>
    p.runParser(s) 

let parseReplCommand = (Parser(p), s: string): parseResult<replCommand> =>
    p.runParser(s)