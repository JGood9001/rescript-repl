open Test
open TestUtils
open ParserCombinators

test("Successfully parses appropriate input for the ':load' command", () => {
    let result = Parser.runParser(loadCommandP, ":load some_filename.res")
    let expected = Some(("", REPLCommands.LoadModule("some_filename.res")))
    equals(expected, result)
})

test("Fails to parse when input for the ':load' command consists of a file with any extension other than .res", () => {
    let result = Parser.runParser(loadCommandP, ":load some_filename.txt")
    let expected = None
    equals(expected, result)
})

test("Successfully parses appropriate input for the ':{' (start multiline mode) command", () => {
    let result = Parser.runParser(startMultiLineCommandP, ":{")
    let expected = Some(("", REPLCommands.StartMultiLineMode))
    equals(expected, result)
})

test("Fails to parse when input for the ':{' (start multiline mode) command is anything aside from ':{'", () => {
    let result = Parser.runParser(startMultiLineCommandP, ":{z")
    let expected = None
    equals(expected, result)
})

test("Successfully parses appropriate input for the '}:' (end multiline mode) command", () => {
    let result = Parser.runParser(endMultiLineCommandP, "}:")
    let expected = Some(("", REPLCommands.EndMultiLineMode))
    equals(expected, result)
})

test("Fails to parse when input for the '}:' (end multiline mode) command is anything aside from '}:'", () => {
    let result = Parser.runParser(endMultiLineCommandP, "}:a")
    let expected = None
    equals(expected, result)
})

test("rescriptCodeStartsWithJsLogP Successfully parses when the string starts with Js.log", () => {
    let result =  Parser.runParser(rescriptCodeStartsWithJsLogP, "Js.log")
    let expected = Some(("", "Js.log"))
    equals(expected, result)
})

test("rescriptCodeStartsWithJsLogP Fails to parse when Js.log is preceded by any arbitrary series of characters", () => {
    let result = Parser.runParser(rescriptCodeStartsWithJsLogP, "dsads Js.log")
    let expected = None
    equals(expected, result)
})

test("rescriptCodeEndsWithJsLogP Successfully parses when the string ends ONLY with ->Js.log", () => {
    let result = Parser.runParser(rescriptCodeEndsWithJsLogP, "->Js.log")
    let expected = Some(("", "->Js.log"))
    equals(expected, result)
})

test("rescriptCodeEndsWithJsLogP Fails to parse when ->Js.log is followed by anything other than an empty string", () => {
    let result = Parser.runParser(rescriptCodeEndsWithJsLogP, "x->Js.log and more")
    let expected = None
    equals(expected, result)
})

// simple tests to verify the Alternative instance is working appropriately
test("rescriptCodeStartsOrEndsWithJsLogP Successfully parses when the string starts with Js.log", () => {
    let result = Parser.runParser(rescriptCodeStartsOrEndsWithJsLogP, "Js.log")
    let expected = Some(("", "Js.log"))
    equals(expected, result)
})

test("rescriptCodeStartsOrEndsWithJsLogP Successfully parses when the string ends ONLY with ->Js.log", () => {
    let result = Parser.runParser(rescriptCodeStartsOrEndsWithJsLogP, "x->Js.log")
    let expected = Some(("", "->Js.log"))
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
