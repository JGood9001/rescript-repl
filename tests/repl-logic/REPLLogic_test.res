open Test
// open TestUtils

// test("Successfully parses the ':load' command", () => {
//     let result = REPLLogic.parseReplCommand(":load Utils")
//     let expected = REPLCommands.LoadModule("Utils")
//     equals(expected, result)
// })

// test("Successfully parses the ':{' (start multiline mode) command", () => {
//     let result = REPLLogic.parseReplCommand(":{")
//     let expected = REPLCommands.StartMultiLineMode
//     equals(expected, result)
// })


// test("Successfully parses the '}:' (end multiline mode) command", () => {
//     let result = REPLLogic.parseReplCommand("}:")
//     let expected = REPLCommands.EndMultiLineMode
//     equals(expected, result)
// })

// test("All other string input yields the RescriptCode command", () => {
//     let result = REPLLogic.parseReplCommand("some user input that won't compile")
//     let expected = REPLCommands.RescriptCode("some user input that won't compile")
//     equals(expected, result)
// })
