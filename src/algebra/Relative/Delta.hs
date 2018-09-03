{-# language MultiParamTypeClasses #-}
{-# language TypeFamilies #-}
{-# language FlexibleContexts #-}
{-# language UndecidableInstances #-}

---------------------------------------------------------------------------------
-- |
-- Copyright :  (c) Edward Kmett 2017-2018
-- License   :  BSD-2-Clause OR Apache-2.0
-- Maintainer:  Edward Kmett <ekmett@gmail.com>
-- Stability :  experimental
-- Portability: non-portable
--
-- Stuff we can measure in UTF-16 code units
---------------------------------------------------------------------------------

module Relative.Delta
  ( Delta(..)
  , HasDelta(..)
  , units
  , HasMonoidalDelta
  , HasOrderedDelta
  , HasRelativeDelta
  ) where

import Data.Profunctor.Unsafe
import Data.Text
import Data.Text.Unsafe

import FingerTree
import Relative.Absolute
import Relative.Class
import Relative.Delta.Type
import Syntax.Alex

--------------------------------------------------------------------------------
-- Something that has a delta
--------------------------------------------------------------------------------

-- | Something we can measure.
class HasDelta t where
  delta :: t -> Delta

-- | extract the number of utf-16 code units from a delta
units :: HasDelta t => t -> Int
units y = case delta y of
  Delta x -> x

instance HasDelta Delta where
  delta = id

instance HasDelta Text where
  delta = Delta . lengthWord16

instance HasDelta a => HasDelta (Absolute a) where
  delta (Absolute a) = delta a

instance (Measured a, HasDelta (Measure a)) => HasDelta (FingerTree a) where
  delta = delta . measure

instance HasDelta AlexInput where
  delta = Delta #. alexInputDelta

--------------------------------------------------------------------------------
-- Monoidal deltas
--------------------------------------------------------------------------------

-- |
-- 'delta' for this type is a monoid homomorphism
--
-- @
-- 'delta' (m '<>' n) = 'delta' m <> 'delta' n
-- 'delta' mempty = 0
-- @
class (Monoid t, HasDelta t) => HasMonoidalDelta t where
instance HasMonoidalDelta Delta
instance HasMonoidalDelta Text
instance HasMonoidalDelta a => HasMonoidalDelta (Absolute a)
instance (Measured a, HasMonoidalDelta (Measure a)) => HasMonoidalDelta (FingerTree a)

--------------------------------------------------------------------------------
-- Monotone deltas
--------------------------------------------------------------------------------

-- |
-- Requires that 'delta' is monotone
--
-- @m <= n@ implies @'delta' m <= 'delta' n@
class (Ord t, HasDelta t) => HasOrderedDelta t
instance HasOrderedDelta Delta
instance HasOrderedDelta a => HasOrderedDelta (Absolute a)

-- TODO: supply old instances for all Coda.Relative.*

--------------------------------------------------------------------------------
-- Relative deltas
--------------------------------------------------------------------------------

-- |
-- 'delta' and 'rel'
--
-- @
-- 'delta' ('rel' d p) = d <> 'delta' p
-- @
class (Relative t, HasDelta t) => HasRelativeDelta t
instance HasRelativeDelta Delta
