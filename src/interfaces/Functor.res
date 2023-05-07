open Utils

module type AT = {
    type t<'a>
}

module type Functor = {
    include AT
    let fmap: ('a => 'b) => t<'a> => t<'b>
}

module TestFunctor = (F: Functor) => {
    let test_id = x => F.fmap(id, x) == x
    let test_compose = x => {
        let f = x => mod(x, 2)
        let g = x => x - 1
        F.fmap(pipe(g, f))(x) == F.fmap(f, (F.fmap(g, x)))
    }
}