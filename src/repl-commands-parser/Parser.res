open Functor
open Applicative
open REPLCommands

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
    let pure = p => Parser({ runParser: _ => None })
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

let parseReplCommand = (Parser(p), s: string): parseResult<replCommand> =>
    p.runParser(s)