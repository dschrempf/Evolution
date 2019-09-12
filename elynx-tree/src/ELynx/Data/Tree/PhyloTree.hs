{-# LANGUAGE FlexibleInstances #-}

{- |
Module      :  ELynx.Data.Tree.PhyloTree
Description :  Phylogenetic trees
Copyright   :  (c) Dominik Schrempf 2019
License     :  GPL-3

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

Creation date: Thu Jan 17 16:08:54 2019.

Phylogenetic nodes have a branch length and a label.

The easiest label type is 'Int': 'PhyloIntLabel'.

Also, the 'L.ByteString' label is needed often: 'PhyloByteStringLabel'.

XXX: This is all too complicated. Maybe I should just define a standard tree object like
> data PhyloTree a = Tree (PhyloLabel a)
and that's it. Forget about type classes like Measurable, Named and so on.

-}


module ELynx.Data.Tree.PhyloTree
  ( PhyloLabel (..)
  , PhyloIntLabel
  , PhyloByteStringLabel
  , removeBrLen
  ) where

import qualified Data.ByteString.Lazy.Builder      as L
import qualified Data.ByteString.Lazy.Char8        as L
import           Data.Function
import           Data.Tree
import           Test.QuickCheck

import           ELynx.Data.Tree.BranchSupportTree
import           ELynx.Data.Tree.MeasurableTree
import           ELynx.Data.Tree.NamedTree

-- | A primitive label type for phylogenetic trees with a name, possibly a
-- branch support value, and a 'Double' branch length.
data PhyloLabel a = PhyloLabel { pLabel :: a
                               , pBrSup :: Maybe Double
                               , pBrLen :: Double }
                 deriving (Read, Show, Eq)

instance Ord a => Ord (PhyloLabel a) where
  compare = compare `on` pLabel

instance Measurable (PhyloLabel a) where
  getLen = pBrLen
  setLen l (PhyloLabel lbl s _)
    | l >= 0 = PhyloLabel lbl s l
    | otherwise = error "Branch lengths cannot be negative."

instance BranchSupportLabel (PhyloLabel a) where
  getBranchSupport = pBrSup
  setBranchSupport Nothing  l = l {pBrSup = Nothing}
  setBranchSupport (Just s) l
    | s > 0 = l {pBrSup = Just s}
    | otherwise = error "Branch support cannot be negative."

instance Arbitrary a => Arbitrary (PhyloLabel a) where
  arbitrary = PhyloLabel
    <$> arbitrary
    <*> (Just <$> choose (0, 100))
    <*> choose (0, 10)

-- | Tree node with 'Int' label.
type PhyloIntLabel = PhyloLabel Int

instance Named PhyloIntLabel where
  getName = L.toLazyByteString . L.intDec . pLabel

-- | Tree node with 'L.ByteString' label. Important for parsing
-- 'ELynx.Import.Tree.Newick' files.
type PhyloByteStringLabel = PhyloLabel L.ByteString

instance Named PhyloByteStringLabel where
  getName = pLabel

-- | Remove branch lengths from tree.
removeBrLen :: Tree (PhyloLabel a) -> Tree a
removeBrLen = fmap pLabel
