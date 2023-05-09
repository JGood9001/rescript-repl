let id = x => x
let pipe = (g, f, x) => x->g->f
let compose = (f, g, x) =>  x->g->f

// λ> (Js.String.slice(~from=2, ~to_=5, "abcdefg") == "cde")->Js.log
// λ> true
let splitAt = (s: string, idx: int): (string, string) => {
    let x = Js.String.slice(~from=0, ~to_=idx, s)
    let y = Js.String.slice(~from=idx, ~to_=Js.String.length(s), s)
    (x, y)
}