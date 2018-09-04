{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecursiveDo #-}

module Main where

import LLVM.AST.Type as AST
import LLVM.IRBuilder.Module
import LLVM.IRBuilder.Monad
import LLVM.IRBuilder.Instruction

import Console.Pretty.LLVM

main :: IO ()
main = ppll_ $ buildModule "exampleModule" $ mdo
  function "add" [(i32, "a"), (i32, "b")] i32 $ \[a, b] -> mdo
    _entry <- block `named` "entry"; do
      c <- add a b
      ret c
