{-# LANGUAGE TemplateHaskell #-}

{- |
Module      :  ELynx.Data.MarkovProcess.SubstitutionModel
Description :  Data type describing substitution model
Copyright   :  (c) Dominik Schrempf 2019
License     :  GPL-3

Maintainer  :  dominik.schrempf@gmail.com
Stability   :  unstable
Portability :  portable

Creation date: Tue Jan 29 19:10:46 2019.

To be imported qualified.

-}

module ELynx.Data.MarkovProcess.SubstitutionModel
  ( -- * Types
    Name
  , Params
  , SubstitutionModel
  -- * Lenses and other accessors
  , alphabet
  , name
  , stationaryDistribution
  , exchangeabilityMatrix
  , getRateMatrix
  , totalRate
  -- * Building substitution models
  , substitutionModel
  , unnormalized
  -- * Transformations
  , scale
  , normalize
  , appendName
  -- * Output
  , summarize
  ) where

import           Control.Lens
import qualified Data.ByteString.Lazy.Char8          as L
import qualified Numeric.LinearAlgebra               as LinAlg

import           ELynx.Data.Alphabet.Alphabet
import qualified ELynx.Data.MarkovProcess.RateMatrix as R
import           ELynx.Tools.Definitions
import           ELynx.Tools.LinearAlgebra
import           ELynx.Tools.Numeric

-- | Name of substitution model; abstracted and subject to change.
type Name = String

-- | Parameters of substitution model. May be the empty list.
type Params = [Double]

-- | Complete definition of a substitution model. Create instances with
-- 'substitutionModel'.
data SubstitutionModel = SubstitutionModel
  { _alphabet               :: Alphabet
  , _name                   :: Name
  , _params                 :: Params
  , _stationaryDistribution :: R.StationaryDistribution
  , _exchangeabilityMatrix  :: R.ExchangeabilityMatrix
  }
  deriving (Show, Read)

makeLenses ''SubstitutionModel

-- | Calculate rate matrix from substitution model.
getRateMatrix :: SubstitutionModel -> R.RateMatrix
getRateMatrix sm = R.fromExchangeabilityMatrix (sm^.exchangeabilityMatrix) (sm^.stationaryDistribution)

-- | Get scale of substitution model.
totalRate :: SubstitutionModel -> Double
totalRate sm = R.totalRate (sm^.stationaryDistribution) (getRateMatrix sm)

-- | Create normalized 'SubstitutionModel'. See 'normalize'.
substitutionModel :: Alphabet -> Name -> Params
                  -> R.StationaryDistribution -> R.ExchangeabilityMatrix
                  -> SubstitutionModel
substitutionModel c n ps d e = normalize $ SubstitutionModel c n ps d e

-- | Create UNNORMALIZED 'SubstitutionModel'. See 'substitutionModel'.
unnormalized :: Alphabet -> Name -> Params
                  -> R.StationaryDistribution -> R.ExchangeabilityMatrix
                  -> SubstitutionModel
unnormalized = SubstitutionModel

-- | Scale the rate of a substitution model by given factor.
scale :: Double -> SubstitutionModel -> SubstitutionModel
scale r = over exchangeabilityMatrix (LinAlg.scale r)

-- | Normalize a substitution model, so that, on average, one substitution
-- happens per unit time.
normalize :: SubstitutionModel -> SubstitutionModel
normalize sm = scale (1.0/r) sm
  where r = totalRate sm

-- | Abbend to name.
appendName :: Name -> SubstitutionModel -> SubstitutionModel
appendName n = over name (<> n)

-- | Summarize a substitution model; lines to be printed to screen or log.
summarize :: SubstitutionModel -> [L.ByteString]
summarize sm = map L.pack $
  (show (sm^.alphabet) ++ " substitution model: " ++ sm^.name ++ ".") :
  [ "Parameters: " ++ show (sm^.params) ++ "." | not (null (sm^.params))] ++
  case sm^.alphabet of
    DNA -> [ "Stationary distribution: " ++ dispv precision (sm^.stationaryDistribution) ++ "."
           , "Exchangeability matrix:\n" ++ dispmi 2 precision (sm^.exchangeabilityMatrix) ++ "."
           , "Scale: " ++ show (roundN precision $ totalRate sm) ++ "."
           ]
    Protein -> [ "Stationary distribution: " ++ dispv precision (sm^.stationaryDistribution) ++ "."
               , "Scale: " ++ show (roundN precision $ totalRate sm) ++ "."
               ]
    _ -> error "Extended character sets are not supported with substitution models."

