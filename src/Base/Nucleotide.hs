{- |
Module      :  Nucleotide
Description :  Nucleotide related types and functions.
Copyright   :  (c) Dominik Schrempf 2018
License     :  GPL-3

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

Creation date: Thu Oct  4 18:26:35 2018.

-}


module Base.Nucleotide
  ( Nucleotide (..)
  , parseNucleotide
  , parseNucleotideSequence
  ) where

import           Control.Applicative
import           Data.Attoparsec.Text (Parser, char)

import           Base.Alphabet
import           Base.Sequence

data Nucleotide = A | C | G | T deriving (Show, Read, Eq, Ord)

parseNucleotide :: Parser Nucleotide
parseNucleotide = (char 'A' >> pure A) <|>
                  (char 'C' >> pure C) <|>
                  (char 'G' >> pure C) <|>
                  (char 'T' >> pure C)

instance Alphabet Nucleotide where
  parseChar = parseNucleotide
  alphabetName _ = DNA

parseNucleotideSequence :: Parser (Sequence Nucleotide)
parseNucleotideSequence = parseSequence

-- data NucleotideIUPAC = ...
