{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingVia #-}

-- |
-- Module      :  ELynx.Tree.Phylogeny
-- Description :  Phylogenetic trees
-- Copyright   :  (c) Dominik Schrempf 2021
-- License     :  GPL-3.0-or-later
--
-- Maintainer  :  dominik.schrempf@gmail.com
-- Stability   :  unstable
-- Portability :  portable
--
-- Creation date: Thu Jan 17 16:08:54 2019.
--
-- The purpose of this module is to facilitate usage of 'Tree's in phylogenetic
-- analyses. A /phylogeny/ is a 'Tree' with unique leaf labels, and unordered
-- sub-forest.
--
-- Using the 'Tree' data type has some disadvantages.
--
-- 1. All trees are rooted. Unrooted trees can be treated with a rooted data
-- structure, as it is used here. However, some functions may be meaningless.
--
-- 2. Changing branch labels, node labels, or the topology of the tree is slow,
-- especially when the changes are close to the leaves of the tree.
--
-- 3. Internally, the underlying 'Tree' data structure stores the sub-forest as
-- an ordered list. Hence, we have to do some tricks when comparing phylogenies
-- (see 'equal'), and comparison is slow.
--
-- 4. Uniqueness of the leaves is not ensured by the data type, but has to be
-- checked at runtime. Functions relying on the tree to have unique leaves do
-- perform this check, and return 'Left' with a message, if the tree has
-- duplicate leaves.
--
-- NOTE: 'Tree's are rooted.
--
-- NOTE: 'Tree's encoded in Newick format correspond to rooted trees. By
-- convention only, a tree parsed from Newick format is usually thought to be
-- unrooted, when the root node is multifurcating and has three or more
-- children. This convention is not used here. Newick trees are just parsed as
-- they are, and a rooted tree is returned.
--
-- A multifurcating root node can be resolved to a bifurcating root node with
-- 'outgroup'.
--
-- The bifurcating root node can be changed with 'outgroup' or 'midpoint'.
--
-- For a given tree with bifurcating root node, a list of all rooted trees is
-- returned by 'roots'.
module ELynx.Tree.Phylogeny
  ( -- * Functions
    equal,
    equal',
    intersect,
    bifurcating,
    outgroup,
    midpoint,
    roots,

    -- * Branch labels
    Phylo (..),
    toPhyloLabel,
    toPhyloTree,
    lengthToPhyloLabel,
    lengthToPhyloTree,
    supportToPhyloLabel,
    supportToPhyloTree,
    toLengthTree,
    toSupportTree,
    PhyloExplicit (..),
    toExplicitTree,
  )
where

import Control.DeepSeq
import Data.Aeson
import Data.Bifoldable
import Data.Bifunctor
import Data.Bitraversable
import Data.List hiding (intersect)
import Data.Maybe
import Data.Monoid
import Data.Semigroup
import Data.Set (Set)
import qualified Data.Set as S
import ELynx.Tree.Bipartition
import ELynx.Tree.Length
import ELynx.Tree.Rooted
import ELynx.Tree.Splittable
import ELynx.Tree.Support
import GHC.Generics

-- | The equality check is slow because the order of children is considered to
-- be arbitrary.
--
-- Return 'Left' if a tree does not have unique leaves.
equal :: (Eq e, Eq a, Ord a) => Tree e a -> Tree e a -> Either String Bool
equal tL tR
  | duplicateLeaves tL = Left "equal: Left tree has duplicate leaves."
  | duplicateLeaves tR = Left "equal: Right tree has duplicate leaves."
  | otherwise = Right $ equal' tL tR

-- | Same as 'equal', but assume that leaves are unique.
equal' :: (Eq e, Eq a) => Tree e a -> Tree e a -> Bool
equal' ~(Node brL lbL tsL) ~(Node brR lbR tsR) =
  (brL == brR)
    && (lbL == lbR)
    && (length tsL == length tsR)
    && all (elem' tsR) tsL
  where
    elem' ts t = isJust $ find (equal' t) ts

-- | Compute the intersection of trees.
--
-- The intersections are the largest subtrees sharing the same leaf set.
--
-- Degree two nodes are pruned with 'prune'.
--
-- Return 'Left' if:
--
-- - the intersection of leaves is empty.
intersect ::
  (Semigroup e, Eq e, Ord a) => Forest e a -> Either String (Forest e a)
intersect ts
  | S.null lvsCommon = Left "intersect: Intersection of leaves is empty."
  | otherwise = case sequence [dropLeavesWith (predicate ls) t | (ls, t) <- zip leavesToDrop ts] of
    Nothing -> Left "intersect: A tree is empty."
    Just ts' -> Right ts'
  where
    -- Leaf sets.
    lvss = map (S.fromList . leaves) ts
    -- Common leaf set.
    lvsCommon = foldl1' S.intersection lvss
    -- Leaves to drop for each tree in the forest.
    leavesToDrop = map (S.\\ lvsCommon) lvss
    -- Predicate.
    predicate lvsToDr l = l `S.member` lvsToDr

-- | Check if a tree is bifurcating.
--
-- A Bifurcating tree only contains degree one (leaves) and degree three nodes
-- (internal bifurcating nodes).
bifurcating :: Tree e a -> Bool
bifurcating (Node _ _ []) = True
bifurcating (Node _ _ [x, y]) = bifurcating x && bifurcating y
bifurcating _ = False

-- | Root the tree using an outgroup.
--
-- NOTE: If the current root node is multifurcating, a bifurcating root node
-- with the empty label is introduced by 'split'ting the leftmost branch. In
-- this case, the 'Monoid' instance of the node label and the 'Splittable'
-- instance of the branch length are used, and the degree of the former root
-- node is decreased by one.
--
-- Given that the root note is bifurcating, the root node is moved to the
-- required position specified by the outgroup.
--
-- Branches are connected according to the provided 'Semigroup' instance.
--
-- Upon insertion of the root node at the required position, the affected branch
-- is 'split' according to the provided 'Splittable' instance.
--
-- Return 'Left' if
--
-- - the root node is a leaf;
--
-- - the root node has degree two;
--
-- - the tree has duplicate leaves;
--
-- - the provided outgroup is not found on the tree or is polyphyletic.
outgroup :: (Semigroup e, Splittable e, Monoid a, Ord a) => Set a -> Tree e a -> Either String (Tree e a)
outgroup _ (Node _ _ []) = Left "outgroup: Root node is a leaf."
outgroup _ (Node _ _ [_]) = Left "outgroup: Root node has degree two."
outgroup o t@(Node _ _ [_, _]) = do
  bip <- bp o (S.fromList (leaves t) S.\\ o)
  rootAt bip t
outgroup o (Node b l ts) = outgroup o t'
  where
    (Node brO lbO tsO) = head ts
    -- Introduce a bifurcating root node.
    t' = Node b mempty [Node (split brO) lbO tsO, Node (split brO) l (tail ts)]

-- The 'midpoint' algorithm is pretty stupid because it calculates all rooted
-- trees and then finds the one minimizing the difference between the heights of
-- the left and right sub tree. Actually, one just needs to move left or right,
-- with the aim to minimize the height difference between the left and right sub
-- tree.

-- | Root tree at the midpoint.
--
-- Return 'Left' if
--
-- - the root node is not bifurcating.
midpoint :: (Semigroup e, Splittable e, HasLength e) => Tree e a -> Either String (Tree e a)
midpoint (Node _ _ []) = Left "midpoint: Root node is a leaf."
midpoint (Node _ _ [_]) = Left "midpoint: Root node has degree two."
midpoint t@(Node _ _ [_, _]) = roots t >>= getMidpoint
midpoint _ = Left "midpoint: Root node is multifurcating."

-- Find the index of the smallest element.
findMinIndex :: Ord a => [a] -> Either String Int
findMinIndex (x : xs) = go (0, x) 1 xs
  where
    go (i, _) _ [] = Right i
    go (i, z) j (y : ys) = if z < y then go (i, z) (j + 1) ys else go (j, y) (j + 1) ys
findMinIndex [] = Left "findMinIndex: Empty list."

getMidpoint :: HasLength e => [Tree e a] -> Either String (Tree e a)
getMidpoint ts = case t of
  Right (Node br lb [l, r]) ->
    let hl = height l
        hr = height r
        dh = (hl - hr) / 2
     in Right $
          Node
            br
            lb
            [ modifyStem (modifyLength (subtract dh)) l,
              modifyStem (modifyLength (+ dh)) r
            ]
  -- Explicitly use 'error' here, because roots is supposed to return trees with
  -- bifurcating root nodes.
  Right _ -> error "getMidpoint: Root node is not bifurcating; please contact maintainer."
  Left e -> Left e
  where
    dhs = map getDeltaHeight ts
    t = (ts !!) <$> findMinIndex dhs

-- find index of minimum; take this tree and move root to the midpoint of the branch

-- Get delta height of left and right sub tree.
getDeltaHeight :: HasLength e => Tree e a -> Length
getDeltaHeight (Node _ _ [l, r]) = abs $ height l - height r
-- Explicitly use 'error' here, because roots is supposed to return trees with
-- bifurcating root nodes.
getDeltaHeight _ = error "getDeltaHeight: Root node is not bifurcating; please contact maintainer."

-- | For a rooted tree with a bifurcating root node, get all possible rooted
-- trees.
--
-- The root node (label and branch) is moved.
--
-- For a tree with @l=2@ leaves, there is one rooted tree. For a bifurcating
-- tree with @l>2@ leaves, there are @(2l-3)@ rooted trees. For a general tree
-- with a bifurcating root node, and a total number of @n>2@ nodes, there are
-- (n-2) rooted trees.
--
-- A bifurcating root is required because moving a multifurcating root node to
-- another branch would change the degree of the root node. To resolve a
-- multifurcating root, please use 'outgroup'.
--
-- Connect branches according to the provided 'Semigroup' instance.
--
-- Split the affected branch into one out of two equal entities according the
-- provided 'Splittable' instance.
--
-- Return 'Left' if the root node is not 'bifurcating'.
roots :: (Semigroup e, Splittable e) => Tree e a -> Either String (Forest e a)
roots (Node _ _ []) = Left "roots: Root node is a leaf."
roots (Node _ _ [_]) = Left "roots: Root node has degree two."
roots t@(Node b c [tL, tR]) = Right $ t : descend b c tR tL ++ descend b c tL tR
roots _ = Left "roots: Root node is multifurcating."

complementaryForests :: Tree e a -> Forest e a -> [Forest e a]
complementaryForests t ts = [t : take i ts ++ drop (i + 1) ts | i <- [0 .. (n -1)]]
  where
    n = length ts

-- From the bifurcating root, descend into one of the two pits.
--
-- descend splitFunction rootBranch rootLabel complementaryTree downwardsTree
descend :: (Semigroup e, Splittable e) => e -> a -> Tree e a -> Tree e a -> Forest e a
descend _ _ _ (Node _ _ []) = []
descend brR lbR tC (Node brD lbD tsD) =
  [ Node brR lbR [Node (split brDd) lbD f, Node (split brDd) lbDd tsDd]
    | (Node brDd lbDd tsDd, f) <- zip tsD cfs
  ]
    ++ concat
      [ descend brR lbR (Node (split brDd) lbD f) (Node (split brDd) lbDd tsDd)
        | (Node brDd lbDd tsDd, f) <- zip tsD cfs
      ]
  where
    brC' = branch tC <> brD
    tC' = tC {branch = brC'}
    cfs = complementaryForests tC' tsD

-- Root a tree at a specific position.
--
-- Root the tree at the branch defined by the given bipartition. The original
-- root node is moved to the new position.
--
-- The root node must be bifurcating (see 'roots' and 'outgroup').
--
-- Connect branches according to the provided 'Semigroup' instance.
--
-- Upon insertion of the root, split the affected branch according to the
-- provided 'Splittable' instance.
--
-- Return 'Left', if:
--
-- - the root node is not bifurcating;
--
-- - the tree has duplicate leaves;
--
-- - the bipartition does not match the leaves of the tree.
rootAt ::
  (Semigroup e, Splittable e, Eq a, Ord a) =>
  Bipartition a ->
  Tree e a ->
  Either String (Tree e a)
rootAt b t
  -- Tree is checked for being bifurcating in 'roots'.
  --
  -- Do not use 'duplicateLeaves' here, because we also need to compare the leaf
  -- set with the bipartition.
  | length lvLst /= S.size lvSet = Left "rootAt: Tree has duplicate leaves."
  | toSet b /= lvSet = Left "rootAt: Bipartition does not match leaves of tree."
  | otherwise = rootAt' b t
  where
    lvLst = leaves t
    lvSet = S.fromList $ leaves t

-- Assume the leaves of the tree are unique.
rootAt' ::
  (Semigroup e, Splittable e, Ord a) =>
  Bipartition a ->
  Tree e a ->
  Either String (Tree e a)
rootAt' b t = do
  ts <- roots t
  case find (\x -> bipartition x == Right b) ts of
    Nothing -> Left "rootAt': Bipartition not found on tree."
    Just t' -> Right t'

-- | Branch label for phylogenetic trees.
--
-- Branches may have a length and a support value.
--
-- Especially useful to export trees to Newick format; see
-- 'ELynx.Tree.Export.Newick.toNewick'.
data Phylo = Phylo
  { pBranchLength :: Maybe Length,
    pBranchSupport :: Maybe Support
  }
  deriving (Read, Show, Eq, Ord, Generic, NFData)

instance Semigroup Phylo where
  Phylo mBL mSL <> Phylo mBR mSR =
    Phylo
      (getSum <$> (Sum <$> mBL) <> (Sum <$> mBR))
      (getMin <$> (Min <$> mSL) <> (Min <$> mSR))

instance HasMaybeLength Phylo where
  getMaybeLength = pBranchLength
  setMaybeLength l x = x {pBranchLength = Just l}

instance HasMaybeSupport Phylo where
  getMaybeSupport = pBranchSupport
  setMaybeSupport s x = x {pBranchSupport = Just s}

instance ToJSON Phylo

instance FromJSON Phylo

-- | Set branch length and support value.
toPhyloLabel :: (HasMaybeLength e, HasMaybeSupport e) => e -> Phylo
toPhyloLabel x = Phylo (getMaybeLength x) (getMaybeSupport x)

-- | See 'toPhyloLabel'.
toPhyloTree :: (HasMaybeLength e, HasMaybeSupport e) => Tree e a -> Tree Phylo a
toPhyloTree = first toPhyloLabel

-- | Set branch length. Do not set support value.
lengthToPhyloLabel :: HasMaybeLength e => e -> Phylo
lengthToPhyloLabel x = Phylo (getMaybeLength x) Nothing

-- | See 'lengthToPhyloLabel'.
lengthToPhyloTree :: HasMaybeLength e => Tree e a -> Tree Phylo a
lengthToPhyloTree = first lengthToPhyloLabel

-- | Set support value. Do not set branch length.
supportToPhyloLabel :: HasMaybeSupport e => e -> Phylo
supportToPhyloLabel x = Phylo Nothing (getMaybeSupport x)

-- | See 'supportToPhyloLabel'.
supportToPhyloTree :: HasMaybeSupport e => Tree e a -> Tree Phylo a
supportToPhyloTree = first supportToPhyloLabel

fromMaybeWithError :: String -> Maybe a -> Either String a
fromMaybeWithError s = maybe (Left s) Right

-- | If root branch length is not available, set it to 0.
--
-- Return 'Left' if any other branch length is unavailable.
toLengthTree :: HasMaybeLength e => Tree e a -> Either String (Tree Length a)
toLengthTree t =
  fromMaybeWithError "toLengthTree: Length unavailable for some branches." $
    getZipBranchTree <$> traverse getMaybeLength (ZipBranchTree $ cleanStemLength t)

cleanStemLength :: HasMaybeLength e => Tree e a -> Tree e a
cleanStemLength = modifyStem f
  where
    f x = case getMaybeLength x of
      Nothing -> setMaybeLength 0 x
      Just _ -> x

-- | Set branch support values of branches leading to the leaves and of the root
-- branch to maximum support.
--
-- Return 'Left' if any other branch has no available support value.
toSupportTree :: HasMaybeSupport e => Tree e a -> Either String (Tree Support a)
toSupportTree t =
  fromMaybeWithError "toSupportTree: Support value unavailable for some branches." $
    getZipBranchTree
      <$> traverse getMaybeSupport (ZipBranchTree $ cleanLeafSupport m $ cleanSupport m t)
  where
    m = getMaxSupport t

-- If all branch support values are below 1.0, set the max support to 1.0.
getMaxSupport :: HasMaybeSupport e => Tree e a -> Support
getMaxSupport = fromJust . max (Just 1.0) . bimaximum . bimap getMaybeSupport (const Nothing)

cleanSupport :: HasMaybeSupport e => Support -> Tree e a -> Tree e a
cleanSupport s = modifyStem f
  where
    f x = case getMaybeSupport x of
      Nothing -> setMaybeSupport s x
      Just _ -> x

cleanLeafSupport :: HasMaybeSupport e => Support -> Tree e a -> Tree e a
cleanLeafSupport s l@(Node _ _ []) = cleanSupport s l
cleanLeafSupport s (Node b l xs) = Node b l $ map (cleanLeafSupport s) xs

-- | Explicit branch label with branch length and branch support value.
data PhyloExplicit = PhyloExplicit
  { eBranchLength :: Length,
    eBranchSupport :: Support
  }
  deriving (Read, Show, Eq, Ord, Generic)

instance Semigroup PhyloExplicit where
  PhyloExplicit bL sL <> PhyloExplicit bR sR = PhyloExplicit (bL + bR) (min sL sR)

instance HasMaybeLength PhyloExplicit where
  getMaybeLength = Just . eBranchLength
  setMaybeLength b pl = pl {eBranchLength = b}

instance HasLength PhyloExplicit where
  getLength = eBranchLength
  modifyLength f (PhyloExplicit l s) = PhyloExplicit (f l) s

instance Splittable PhyloExplicit where
  split l = l {eBranchLength = b'}
    where
      b' = eBranchLength l / 2.0

instance HasMaybeSupport PhyloExplicit where
  getMaybeSupport = Just . eBranchSupport
  setMaybeSupport s pl = pl {eBranchSupport = s}

instance HasSupport PhyloExplicit where
  getSupport = eBranchSupport
  modifySupport f (PhyloExplicit l s) = PhyloExplicit l (f s)

instance ToJSON PhyloExplicit

instance FromJSON PhyloExplicit

-- | Conversion to a 'PhyloExplicit' tree.
--
-- See 'toLengthTree' and 'toSupportTree'.
toExplicitTree ::
  (HasMaybeLength e, HasMaybeSupport e) =>
  Tree e a ->
  Either String (Tree PhyloExplicit a)
toExplicitTree t = do
  lt <- toLengthTree t
  st <- toSupportTree t
  case zipTreesWith PhyloExplicit const lt st of
    -- Explicit use of error, since this case should never happen.
    Nothing -> error "toExplicitTree: Can not zip two trees with different topologies."
    Just zt -> return zt
