module Coda.Version
  ( version
  ) where

import Data.List (intercalate)
import Data.Version
import qualified Paths_coda_common

-- | Grab the version number from this project.
version :: String
version = intercalate "." $ show <$> tail (versionBranch Paths_coda_common.version)
