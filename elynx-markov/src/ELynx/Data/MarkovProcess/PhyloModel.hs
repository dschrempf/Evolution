-- |
-- Module      :  ELynx.Data.MarkovProcess.PhyloModel
-- Description :  Phylogenetic model
-- Copyright   :  (c) Dominik Schrempf 2021
-- License     :  GPL-3.0-or-later
--
-- Maintainer  :  dominik.schrempf@gmail.com
-- Stability   :  unstable
-- Portability :  portable
--
-- Creation date: Fri Feb  1 12:43:06 2019.
--
-- A phylogenetic model is a complete description of the evolutionary process. At
-- the moment, it is either a mixture model or a plain substitution model, but more
-- complicated models may be added in the future.
--
-- To be imported qualified.
module ELynx.Data.MarkovProcess.PhyloModel
  ( PhyloModel (..),
    getAlphabet,
  )
where

import ELynx.Data.Alphabet.Alphabet
import qualified ELynx.Data.MarkovProcess.MixtureModel as M
import qualified ELynx.Data.MarkovProcess.SubstitutionModel as S

-- | A phylogenetic model is a mixture model or a substitution model. More
-- complicated models may be added.
data PhyloModel = MixtureModel M.MixtureModel | SubstitutionModel S.SubstitutionModel
  deriving (Show, Read)

-- | Extract code from phylogenetic model.
getAlphabet :: PhyloModel -> Alphabet
getAlphabet (MixtureModel mm) = M.alphabet mm
getAlphabet (SubstitutionModel sm) = S.alphabet sm
