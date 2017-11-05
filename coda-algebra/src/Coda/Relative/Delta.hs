{-# language DeriveGeneric #-}
{-# language DeriveDataTypeable #-}
{-# language GeneralizedNewtypeDeriving #-}
{-# language MultiParamTypeClasses #-}
{-# language TypeFamilies #-}
{-# language FlexibleContexts #-}
{-# language UndecidableInstances #-}

---------------------------------------------------------------------------------
-- |
-- Copyright :  (c) Edward Kmett 2017
-- License   :  BSD2
-- Maintainer:  Edward Kmett <ekmett@gmail.com>
-- Stability :  experimental
-- Portability: non-portable
--
-- Stuff we an measure in UTF-16 code units
---------------------------------------------------------------------------------

module Coda.Relative.Delta
  ( Delta(..)
  , HasDelta(..)
  , units
  , HasMonoidalDelta
  , HasOrderedDelta
  ) where

import Coda.Relative.Delta.Type
import Data.Data
import Data.Default
import Data.Hashable
import Data.Semigroup
import Data.Text
import Data.Text.Unsafe
import GHC.Generics
import Text.Read

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

--------------------------------------------------------------------------------
-- Monotone deltas
--------------------------------------------------------------------------------

-- |
-- Requires that 'delta' is monotone
--
-- @m <= n@ implies @'delta' m <= 'delta' n@
class (Ord t, HasDelta t) => HasOrderedDelta t
instance HasOrderedDelta Delta

-- TODO: supply old instances for all Coda.Relative.*
