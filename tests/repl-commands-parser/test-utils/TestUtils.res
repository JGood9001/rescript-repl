open Test

let intEqual = (~message=?, a: int, b: int) =>  assertion(~message?, ~operator="Int equals", (a, b) => a === b, a, b)
let equals = (~message=?, a, b) =>  assertion(~message?, ~operator="equals", (a, b) => a == b, a, b)