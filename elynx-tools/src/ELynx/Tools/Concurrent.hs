{-# LANGUAGE ScopedTypeVariables #-}
{- |
Module      :  ELynx.Tools.Concurrent
Description :  Tools for concurrent random calculations
Copyright   :  (c) Dominik Schrempf 2020
License     :  GPL-3.0-or-later

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

Creation date: Tue May  7 10:33:24 2019.

-}

module ELynx.Tools.Concurrent
  (
    -- * MWC
    splitGen
    -- * Concurrent calculations
  , parComp
  , getChunks
  )
where

import           Control.Concurrent
import           Control.Concurrent.Async
import           Control.Monad
import           Control.Monad.Primitive
import qualified Data.Vector                   as V
import           Data.Word
import           System.Random.MWC

-- | Split a generator.
splitGen :: PrimMonad m => Int -> Gen (PrimState m) -> m [Gen (PrimState m)]
splitGen n gen
  | n <= 0 = return []
  | otherwise = do
    seeds :: [V.Vector Word32] <- replicateM n $ uniformVector gen 256
    mapM initialize seeds

-- -- XXX: This just doesn't work... The only thing I found:
-- -- https://stackoverflow.com/a/16250010.
-- parComp :: (PrimMonad m, Monoid b) => Int -> (Int -> Gen (PrimState m) -> m b)
--         -> Gen (PrimState m) -> m b
-- parComp num fun gen = do
--   let ncap   = ceiling (fromIntegral num / fromIntegral chunksize :: Double)
--       chunks = getChunks ncap num
--   gs <- splitGen ncap gen
--   mconcat <$> P.mapM (\(n', g') -> fun n' g') (zip chunks gs)

-- | Perform random calculation in parallel. Does only work with 'IO' and the moment.
parComp :: Int -> (Int -> GenIO -> IO b) -> GenIO -> IO [b]
parComp num fun gen = do
  ncap <- getNumCapabilities
  let chunks = getChunks ncap num
  gs <- splitGen ncap gen
  mapConcurrently (uncurry fun) (zip chunks gs)

-- | For a given number of capabilities and number of calculations, get chunk
-- sizes. The chunk sizes will be as evenly distributed as possible and sum up
-- to the number of calculations.
getChunks :: Int -> Int -> [Int]
getChunks c n = ns
 where
  n' = n `div` c
  r  = n `mod` c
  ns = replicate r (n' + 1) ++ replicate (c - r) n'
