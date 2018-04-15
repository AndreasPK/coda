{-# language DeriveGeneric, DeriveAnyClass, TemplateHaskell #-}
module Console.Options where

import Control.Lens
import Data.Default.Class
import GHC.Generics
import Options.Applicative as Options

import Console.Pretty

data ConsoleOptions = ConsoleOptions
  { _consoleFancyOptions :: FancyOptions
  }
  deriving (Show,Generic,Default)

parseConsoleOptions :: Options.Parser ConsoleOptions
parseConsoleOptions = ConsoleOptions <$> parseFancyOptions

makeClassy ''ConsoleOptions

instance HasFancyOptions ConsoleOptions where
  fancyOptions = consoleFancyOptions
