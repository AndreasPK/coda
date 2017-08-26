--------------------------------------------------------------------------------
-- |
-- Copyright :  (c) Edward Kmett 2012-2017
-- License   :  BSD2
-- Maintainer:  Edward Kmett <ekmett@gmail.com>
-- Stability :  experimental
-- Portability: non-portable
--
-- This module provides a @tasty@ test suite for coda
--
-- Test modules are distributed throughout the src folder,
-- but are not built as part of the @coda@ library
--
--------------------------------------------------------------------------------

module Main where

import Coda.Server.Protocol.Test (protocolTests)
import Test.Tasty
-- import Test.Tasty.HUnit

main :: IO ()
main = defaultMain $ testGroup "coda" 
  [ testGroup "server"
    [ protocolTests
    ]
  ]
