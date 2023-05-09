// class Applicative f => Alternative f where
//   empty :: f a
//   (<|>) :: f a -> f a -> f a

//   some :: f a -> f [a]
//   many :: f a -> f [a]

// instance Alternative Maybe where
//   empty               = Nothing
//   -- Note that this could have been written more compactly.
//   Nothing <|> Nothing = Nothing -- 0 results + 0 results = 0 results
//   Just x  <|> Nothing = Just x  -- 1 result  + 0 results = 1 result
//   Nothing <|> Just x  = Just x  -- 0 results + 1 result  = 1 result
//   Just x  <|> Just y  = Just x  -- 1 result  + 1 result  = 1 result:
//                                 -- Maybe can only hold up to one result,
//                                 -- so we discard the second one.

// instance Alternative [] where
//   empty = []
//   (<|>) = (++) -- length xs + length ys = length (xs ++ ys)

open Utils
open Applicative

module type Alternative = {
    include Applicative
    let empty: t<'a>
    let alternative: t<'a> => t<'a> => t<'a>
    let some: t<'a> => t<'a>
}
