{-# language CPP #-}
{-# language BangPatterns #-}
{-# language TypeFamilies #-}
{-# language ViewPatterns #-}
{-# language PatternSynonyms #-}
{-# language FlexibleContexts #-}
{-# language FlexibleInstances #-}
{-# language MultiParamTypeClasses #-}

---------------------------------------------------------------------------------
-- |
-- Copyright :  (c) Edward Kmett 2017
-- License   :  BSD2
-- Maintainer:  Edward Kmett <ekmett@gmail.com>
-- Stability :  experimental
-- Portability: non-portable
--
---------------------------------------------------------------------------------

module Coda.Relative.Cat
  ( Cat
  , snocCat
  , singleton
  ) where

import Control.Lens
import Coda.Relative.Class
import Coda.Relative.Foldable
import Coda.Relative.Queue
import Data.Default
import Data.Function (on)
import Data.List (unfoldr)
import Data.Semigroup
import GHC.Exts as Exts
import Text.Read

-- invariant, all recursive cat's are non-empty
data Cat a = E | C a (Queue (Cat a))
#if __GLASGOW_HASKELL__ >= 802
{-# complete_patterns ((:<)|C),(Empty|E) #-}
#endif

instance Default (Cat a) where
  def = E

instance Relative a => Relative (Cat a) where
  rel _ E = E
  rel 0 xs = xs
  rel d (C a as) = C (rel d a) (rel d as)
  {-# inline rel #-}

instance RelativeFoldable Cat where
  rnull E = True
  rnull _ = False
  {-# inline rnull #-}

  rfoldMap f !d (C a as) = f d a `mappend` rfoldMap (rfoldMap f) d as
  rfoldMap _ _ E = mempty

instance Relative a => Semigroup (Cat a) where
  xs <> E = xs
  E <> xs = xs
  C x xs <> ys = link x xs ys
  {-# inline (<>) #-}

instance Relative a => Monoid (Cat a) where
  mempty = E
  mappend = (<>)

link :: Relative a => a -> Queue (Cat a) -> Cat a -> Cat a
link x q ys = C x (snocQ q ys)
{-# inline link #-}

-- O(1 + e) where e is the # of empty nodes in the queue
linkAll :: Relative a => Queue (Cat a) -> Cat a
linkAll q = case uncons q of
  Just (cat@(C a t), q')
    | rnull q'  -> cat
    | otherwise -> link a t (linkAll q')
  Just (E, q') -> linkAll q' -- recursive case
  Nothing -> E

instance (Relative a, Relative b) => Cons (Cat a) (Cat b) a b where
  _Cons = prism kons unkons where
    kons (a, E) = C a def
    kons (a, ys) = link a def ys
    {-# inline conlike kons #-}
    unkons E = Left E
    unkons (C a q) = Right (a, linkAll q)
    {-# inline unkons #-}

instance Relative a => IsList (Cat a) where
  type Item (Cat a) = a
  fromList = foldr cons E
  {-# inline fromList #-}
  toList = unfoldr uncons
  {-# inline toList #-}

singleton :: a -> Cat a
singleton a = C a def
{-# inline conlike singleton #-}

snocCat :: Relative a => Cat a -> a -> Cat a
snocCat xs a = xs <> singleton a
{-# inline snocCat #-}

instance (Show a, Relative a) => Show (Cat a) where
  showsPrec d = showsPrec d . Exts.toList

instance (Read a, Relative a) => Read (Cat a) where
  readPrec = Exts.fromList <$> readPrec

instance (Eq a, Relative a) => Eq (Cat a) where
  (==) = (==) `on` Exts.toList
  {-# inline (==) #-}

instance (Ord a, Relative a) => Ord (Cat a) where
  compare = compare `on` Exts.toList
  {-# inline compare #-}

