open Test
open TestUtils
open ParserCombinators

test("Successfully parses appropriate input for the ':load' command", () => {
    let result = Parser.parseReplCommand(loadCommandP, ":load some_filename.res")
    let expected = Some(("", REPLCommands.LoadModule("some_filename.res")))
    equals(expected, result)
})

test("Fails to parse when input for the ':load' command consists of a file with any extension other than .res", () => {
    let result = Parser.parseReplCommand(loadCommandP, ":load some_filename.txt")
    let expected = None
    equals(expected, result)
})

test("Successfully parses appropriate input for the ':{' (start multiline mode) command", () => {
    let result = Parser.parseReplCommand(startMultiLineCommandP, ":{")
    let expected = Some(("", REPLCommands.StartMultiLineMode))
    equals(expected, result)
})

test("Fails to parse when input for the ':{' (start multiline mode) command is anything aside from ':{'", () => {
    let result = Parser.parseReplCommand(startMultiLineCommandP, ":{z")
    let expected = None
    equals(expected, result)
})

test("Successfully parses appropriate input for the '}:' (end multiline mode) command", () => {
    let result = Parser.parseReplCommand(endMultiLineCommandP, "}:")
    let expected = Some(("", REPLCommands.EndMultiLineMode))
    equals(expected, result)
})

test("Fails to parse when input for the '}:' (end multiline mode) command is anything aside from '}:'", () => {
    let result = Parser.parseReplCommand(endMultiLineCommandP, "}:a")
    let expected = None
    equals(expected, result)
})

// TODO: write tests for the primitive combinators as well.
// let Parser(hi_parser) = str("hi")
// Js.log(hi_parser.runParser("is it sunny?")) => undefined
// Js.log(hi_parser.runParser("hi, and more")) => [ ', and more', 'hi' ]
// The basic string parser works as expected...

// let Parser(transform_p) = ParserApplicative.fmap(Js.String.toUpperCase, str("hi"))
// Js.log(transform_p.runParser("hi, and more")) => [ ', and more', 'HI' ]

// One property is that you want to have only 1 Some in the array at a time or none at all
// [
//     Parser.parseReplCommand(loadCommandP, s),
//     Parser.parseReplCommand(startMultiLineCommandP, s),
//     Parser.parseReplCommand(endMultiLineCommandP, s)
// ]
// let xs = [Some(1), None, None]
// Belt.Array.some(xs, x => Belt.Option.isSome(x))->ignore
