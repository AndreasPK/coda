{-# language GADTs #-}
{-# language OverloadedLists #-}
{-# language ViewPatterns #-}
module Coda.Automata.NFA 
  ( NFA(..)
  , reverse
  , complement
  , union
  , intersection
  , concat
  , star
  -- derivative parsing
  , prefix, prefixes
  , suffix, suffixes
  , accepts
  ) where

import Coda.Automata.Internal
import qualified Coda.Set.Lazy as Set
import qualified Data.List as List
import Prelude hiding (product, sum, reverse, concat)

-- nfa reversal
reverse :: NFA a -> NFA a
reverse (NFA ss i f d) = NFA ss f i $ \ a t -> Set.filter (Set.member t . d a) ss

-- nfa complement
complement :: NFA a -> NFA a
complement = dfa2nfa . go . nfa2dfa where
  go (DFA ss is fs d) = DFA ss is (Set.difference ss fs) d

-- kleene star
star :: NFA a -> NFA a
star (NFA ss is fs d) = NFA ss is fs $ \a (d a -> r) ->
  if intersects fs r
  then Set.union r is
  else r

-- concatenate two automata
concat :: NFA a -> NFA a -> NFA a
concat (NFA ss is fs d)
       (NFA ss' (Set.mapMonotonic Right -> is') (Set.mapMonotonic Right -> fs') d')
  = NFA (Set.sum ss ss') (Set.mapMonotonic Left is) fs' $ \a s -> case s of
     Right s' -> Set.mapMonotonic Right (d' a s')
     Left (d a -> r) | r' <- Set.mapMonotonic Left r -> 
       if intersects r fs 
       then Set.union r' is'
       else r'

-- nfa union
union :: NFA a -> NFA a -> NFA a
union (NFA ss is fs d) (NFA ss' is' fs' d') 
  = NFA (Set.sum ss ss') (Set.sum is is') (Set.sum fs fs') $ \a s -> case s of
    Left s' -> Set.mapMonotonic Left (d a s')
    Right s' -> Set.mapMonotonic Right (d' a s') 

-- nfa intersection
intersection :: NFA a -> NFA a -> NFA a
intersection (NFA ss is fs d) (NFA ss' is' fs' d')
  = NFA (Set.product ss ss') (Set.product is is') (Set.product fs fs') $ \ a (s,s') -> Set.product (d a s) (d' a s')

--------------------------------------------------------------------------------
-- derivative parsing
--------------------------------------------------------------------------------

-- feed a single prefix
prefix :: a -> NFA a -> NFA a
prefix a (NFA ss is fs d) = NFA ss (nondet d a is) fs d

-- feed a long prefix
prefixes :: [a] -> NFA a -> NFA a
prefixes as (NFA ss is fs d) = NFA ss (nondets d as is) fs d

-- feed a single suffix
suffix :: NFA a -> a -> NFA a
suffix (NFA ss is fs d) a = NFA ss is (Set.filter (intersects fs . d a) ss) d

-- feed a long suffix
suffixes :: NFA a -> [a] -> NFA a
suffixes (NFA ss is fs d) as = NFA ss is (nondets d' (List.reverse as) fs) d where
  d' a t = Set.filter (Set.member t . d a) ss

-- check to see if we accepts the empty string
accepts :: NFA a -> Bool
accepts (NFA _ is fs _) = intersects is fs
