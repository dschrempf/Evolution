{- |
Module      :  EvoMod.Import.Tree.Newick
Description :  Import Newick trees.
Copyright   :  (c) Dominik Schrempf 2019
License     :  GPL-3

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

Creation date: Thu Jan 17 14:56:27 2019.

Code partly taken from Biobase.Newick.Import.

[Specifications](http://evolution.genetics.washington.edu/phylip/newicktree.html)

- In particular, no conversion from _ to (space) is done right now.

-}


module EvoMod.Import.Tree.Newick
  ( Parser
  , newick
  , manyNewick
  , forest
  , leaf
  , node
  , name
  , branchLength
  ) where

import           Text.Megaparsec
import           Text.Megaparsec.Byte
import           Text.Megaparsec.Byte.Lexer (decimal, float)

import qualified Data.ByteString.Lazy            as B
import           Data.Tree
import           Data.Void
import           Data.Word

import           EvoMod.Data.Tree.PhyloTree
import           EvoMod.Tools               (c2w)

-- | A shortcut.
type Parser = Parsec Void B.ByteString

-- | Parse many Newick trees.
manyNewick :: Parser [PhyloByteStringTree]
manyNewick = some (newick <* space) <* eof <?> "manyNewick"

-- | Parse a Newick tree.
newick :: Parser PhyloByteStringTree
newick = tree <* char (c2w ';') <?> "newick"

tree :: Parser PhyloByteStringTree
tree = space *> (branched <|> leaf) <?> "tree"

branched :: Parser PhyloByteStringTree
branched = do
  f <- forest
  n <- node
    <?> "branched"
  return $ Node n f

-- | A 'forest' is a set of trees separated by @,@ and enclosed by parentheses.
forest :: Parser [PhyloByteStringTree]
forest = char (c2w '(') *> tree `sepBy1` char (c2w ',') <* char (c2w ')') <?> "forest"

-- | A 'leaf' is a 'node' without children.
leaf :: Parser PhyloByteStringTree
leaf = do
  n <- node
    <?> "leaf"
  return $ Node n []

-- | A 'node' has a name and a 'branchLength'.
node :: Parser PhyloByteStringLabel
node = do
  n <- name
  b <- branchLength
    <?> "node"
  return $ PhyloLabel n b

checkNameCharacter :: Word8 -> Bool
checkNameCharacter c = c `notElem` map c2w " :;()[],"

-- | A name can be any string of printable characters except blanks, colons,
-- semicolons, parentheses, and square brackets (and commas).
name :: Parser B.ByteString
name = B.pack <$> many (satisfy checkNameCharacter) <?> "name"

-- | Branch lengths default to 0.
branchLength :: Parser Double
branchLength = char (c2w ':') *> branchLengthGiven <|> pure 0 <?> "branchLength"

branchLengthGiven :: Parser Double
branchLengthGiven = try float <|> (fromIntegral <$> (decimal :: Parser Int))