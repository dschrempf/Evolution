{- |
Module      :  Main
Description :  Work with molecular sequence data
Copyright   :  (c) Dominik Schrempf 2019
License     :  GPL-3

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

Creation date: Thu Sep  5 21:53:07 2019.

-}

module Main where

import           Control.Monad.Trans.Reader

import           Options

import           Concatenate.Concatenate
import           Examine.Examine
import           Filter.Filter
import           Simulate.Simulate
import           SubSample.SubSample
import           Translate.Translate

import           ELynx.Tools.Logger

main :: IO ()
main = do
  (Arguments g c) <- parseArguments
  case c of
    Concatenate a ->
      runReaderT (eLynxWrapper concatenateDescription a $ concatenateCmd a) g
    Examine a -> runReaderT (eLynxWrapper examineDescription a $ examineCmd a) g
    FilterRows a ->
      runReaderT (eLynxWrapper filterRowsDescription a $ filterRowsCmd a) g
    FilterCols a ->
      runReaderT (eLynxWrapper filterColumnsDescription a $ filterColsCmd a) g
    Simulate a ->
      runReaderT (eLynxWrapper simulateDescription a $ simulateCmd a) g
    SubSample a ->
      runReaderT (eLynxWrapper subSampleDescription a $ subSampleCmd a) g
    Translate a ->
      runReaderT (eLynxWrapper translateDescription a $ translateCmd a) g
