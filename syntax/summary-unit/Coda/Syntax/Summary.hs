module Coda.Syntax.Summary
  ( Summary
  , summarize
  , mergeSummary
  ) where

import Coda.Relative.Delta.Type
import Coda.Syntax.Dyck
import Data.Text

type Summary = ()

summarize :: Text -> Dyck -> Summary
summarize _ _ = ()

mergeSummary :: Int -> Delta -> Summary -> Int -> Delta -> Summary -> Summary
mergeSummary _ _ _ _ _ _ = ()
