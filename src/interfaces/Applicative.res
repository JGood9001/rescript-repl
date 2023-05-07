open Utils
open Functor

// equivalent:
// f <$> x <*> y
// f->fmap(x)->apply(y)
module type Applicative = {
    include Functor
    let pure: 'a => t<'a>
    let apply: t<('a => 'b)> => t<'a> => t<'b>
}

module TestApplicative = (A: Applicative) => {
    let test_id = x => (A.pure(id)->A.apply(x)) == x    
    let test_hom = (f, x) => (A.pure(f)->A.apply(A.pure(x))) == A.pure(f(x))
    // A.t<('a => 'b)> => 'a => bool
    let test_interchange = (u, y) => (u->A.apply(A.pure(y))) == (A.pure(f => f(y))->A.apply(u))
    // A.t<('a => 'b)> => A.t<('c => 'a)> => A.t<'c> => bool
    let test_composition = (u, v, w) =>
        (A.pure(compose)->A.apply(u)->A.apply(v)->A.apply(w)) == u->A.apply(v -> A.apply(w))
}