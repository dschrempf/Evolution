{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}

{- |
Module      :  ELynx.Data.Alphabet.Character
Description :  Alphabet characters
Copyright   :  (c) Dominik Schrempf 2020
License     :  GPL-3.0-or-later

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

Creation date: Sun May 19 21:06:38 2019.

-}

module ELynx.Data.Alphabet.Character
  ( Character
  , toWord
  , fromWord
  , toChar
  , fromChar
  , toString
  , fromString
  , toCVec
  , fromCVec
  )
where

import qualified Data.Vector.Unboxed           as V
import           Data.Vector.Unboxed.Deriving
import           Data.Word8

import qualified ELynx.Data.Character.Character
                                               as C
import           ELynx.Tools

-- | Alphabet characters; abstracted so that representation can be changed at
-- some point.
newtype Character = Character Word8
  deriving (Read, Show, Eq, Ord, Bounded)

-- | Conversion of 'Character's.
toWord :: Character -> Word8
toWord (Character w) = w

-- | Conversion of 'Character's.
fromWord :: Word8 -> Character
fromWord = Character

-- | Conversion of 'Character's.
toChar :: Character -> Char
toChar (Character w) = w2c w

-- | Conversion of 'Character's.
fromChar :: Char -> Character
fromChar = Character . c2w

-- | Conversion of 'Character's.
toString :: [Character] -> String
toString = map toChar

-- | Conversion of 'Character's.
fromString :: String -> [Character]
fromString = map fromChar

-- | Conversion of 'Character's.
toCVec :: C.Character a => V.Vector Character -> V.Vector a
toCVec = V.map (C.fromWord . toWord)

-- | Conversion of 'Character's.
fromCVec :: C.Character a => V.Vector a -> V.Vector Character
fromCVec = V.map (fromWord . C.toWord)

derivingUnbox "Character"
    [t| Character -> Word8 |]
    [| \(Character w) -> w |]
    [| Character |]

