{- |
Module      :  Shuffle.Options
Description :  Options for the connect subcommand
Copyright   :  (c) Dominik Schrempf 2019
License     :  GPL-3

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

Creation date: Thu Sep 19 15:02:21 2019.

-}

module Shuffle.Options
  ( ShuffleArguments (..)
  , Shuffle
  , shuffleArguments
  ) where

import           Control.Monad.Logger
import           Control.Monad.Trans.Reader
-- import           Data.Word
import           Options.Applicative

-- import           ELynx.Tools.Options

-- | Arguments of shuffle command.
data ShuffleArguments = ShuffleArguments
  { newickIqTreeFlag :: Bool
  , nReplicates      :: Int
  , inFile           :: FilePath }
  -- -- TODO. Too complicated at the moment with MWC, use MonadRandom, but then
  -- -- seed option would not match other commands, so leave the option out for
  -- -- now. Maybe, when working on this, try using splitmix consistently.
  --
  -- -- | Seed of NRG, random if 'Nothing'.
  -- , argsSeed         :: Maybe [Word32] }

-- | Logger and reader data type.
type Shuffle = LoggingT (ReaderT ShuffleArguments IO)

-- | Parse arguments of shuffle command.
shuffleArguments :: Parser ShuffleArguments
shuffleArguments = ShuffleArguments
  <$> newickIqTree
  <*> n
  <*> file
  -- <*> seedOpt

newickIqTree :: Parser Bool
newickIqTree = switch $
  long "newick-iqtree"
  <> short 'i'
  <> help "Use IQ-TREE Newick format (internal node labels are branch support values)"

n :: Parser Int
n = option auto $
  long "replicates"
  <> short 'n'
  <> metavar "N"
  <> value 1
  <> help "Number of trees to generate"

file :: Parser FilePath
file = strArgument $
  metavar "TREE-FILE"
  <> help "File containing a Newick tree"