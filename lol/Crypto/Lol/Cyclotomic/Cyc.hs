{-|
Module      : Crypto.Lol.Cyclotomic.Cyc
Description : An implementation of cyclotomic rings that hides and
              automatically manages the internal representations of
              ring elements.
Copyright   : (c) Eric Crockett, 2011-2018
                  Chris Peikert, 2011-2018
License     : GPL-3
Maintainer  : ecrockett0@gmail.com
Stability   : experimental
Portability : POSIX

  \( \def\Z{\mathbb{Z}} \)
  \( \def\F{\mathbb{F}} \)
  \( \def\Q{\mathbb{Q}} \)
  \( \def\Tw{\text{Tw}} \)
  \( \def\Tr{\text{Tr}} \)
  \( \def\O{\mathcal{O}} \)

An implementation of cyclotomic rings that hides the
internal representations of ring elements (e.g., the choice of
basis), and also offers more efficient storage and operations on
subring elements (including elements from the base ring itself).

For an implementation that allows (and requires) the programmer to
control the underlying representation, see
"Crypto.Lol.Cyclotomic.CycRep".

__WARNING:__ as with all fixed-point arithmetic, the functions
associated with 'Cyc' may result in overflow (and thereby
incorrect answers and potential security flaws) if the input
arguments are too close to the bounds imposed by the base type.
The acceptable range of inputs for each function is determined by
the internal linear transforms and other operations it performs.
-}

{-# LANGUAGE ConstraintKinds            #-}
{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE InstanceSigs               #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE NoImplicitPrelude          #-}
{-# LANGUAGE PartialTypeSignatures      #-}
{-# LANGUAGE PolyKinds                  #-}
{-# LANGUAGE RankNTypes                 #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE StandaloneDeriving         #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE TypeOperators              #-}
{-# LANGUAGE UndecidableInstances       #-}

module Crypto.Lol.Cyclotomic.Cyc
(
-- * Data type
  Cyc
-- * Constructors/deconstructors
, UnCyc(..)
) where

import qualified Algebra.Additive     as Additive (C)
import qualified Algebra.Module       as Module (C)
import qualified Algebra.Ring         as Ring (C)
import qualified Algebra.ZeroTestable as ZeroTestable (C)

import           Crypto.Lol.CRTrans
import           Crypto.Lol.Cyclotomic.CycRep   hiding (coeffsDec,
                                                 coeffsPow, crtSet,
                                                 gSqNorm, powBasis)
import qualified Crypto.Lol.Cyclotomic.CycRep   as R
import           Crypto.Lol.Cyclotomic.Language hiding (Dec, Pow)
import qualified Crypto.Lol.Cyclotomic.Language as L
import           Crypto.Lol.Cyclotomic.Tensor   (Tensor, TensorCRTSet,
                                                 TensorGaussian)
import           Crypto.Lol.Gadget
import           Crypto.Lol.Prelude             as LP
import           Crypto.Lol.Reflects
import           Crypto.Lol.Types               (RRq, ZqBasic)
import           Crypto.Lol.Types.FiniteField
import           Crypto.Lol.Types.IFunctor
import           Crypto.Lol.Types.Proto
import           Crypto.Lol.Types.ZPP

import           Control.Applicative    hiding ((*>))
import           Control.Arrow
import           Control.DeepSeq
import           Control.Monad.Identity
import           Control.Monad.Random   hiding (lift)
import           Data.Coerce
import           Data.Constraint        ((:-), Dict (..), (\\))
import qualified Data.Constraint        as C
import           Data.Traversable

-- | Underlying GADT for a cyclotomic ring in one of several
-- representations.
data CycG t m r where
  Pow :: !(CycRep t P m r) -> CycG t m r
  Dec :: !(CycRep t D m r) -> CycG t m r
  CRT :: !(CycRepEC t m r) -> CycG t m r
  -- super-optimized storage of scalars
  Scalar :: !r -> CycG t m r
  -- optimized storage of subring elements
  Sub :: (l `Divides` m) => !(CycG t l r) -> CycG t m r
  -- CJP: someday try to merge the above two?

-- | A cyclotomic ring such as \( \Z[\zeta_m] \), \( \Z_q[\zeta_m] \),
-- or \( \Q[\zeta_m] \): @t@ is the 'Tensor' type for storing
-- coefficient tensors; @m@ is the cyclotomic index; @r@ is the base
-- ring of the coefficients (e.g., \(\ \Q \), \( \Z \), \( \Z_q \)).
data family Cyc (t :: Factored -> * -> *) (m :: Factored) r

-- could also do an Int instance
newtype instance Cyc t m Double        = CycDbl { unCycDbl :: CycG t m Double }
newtype instance Cyc t m Int64         = CycI64 { unCycI64 :: CycG t m Int64 }
newtype instance Cyc t m (ZqBasic q z) = CycZqB { unCycZqB :: CycG t m (ZqBasic q z) }

-- | cyclotomic over a product base ring, represented as a product of
-- cyclotomics over the individual rings
data    instance Cyc t m (a,b)         = CycPair !(Cyc t m a) !(Cyc t m b)

-- | cyclotomic ring of integers with unbounded precision, limited to
-- powerful- or decoding-basis representation.
data instance Cyc t m Integer
  = PowIgr !(CycRep t P m Integer)
  | DecIgr !(CycRep t D m Integer)

-- | additive group \( K/qR \), limited to powerful- or decoding-basis
-- representation
data instance Cyc t m (RRq q r)
  = PowRRq !(CycRep t P m (RRq q r))
  | DecRRq !(CycRep t D m (RRq q r))

---------- Constructors / destructors ----------

-- | Convenience wrapper.
cycPC :: Either (CycRep t P m r) (CycRep t C m r) -> CycG t m r
cycPC = either Pow (CRT . Right)
{-# INLINABLE cycPC #-}

-- | Convenience wrapper.
cycPE :: Either (CycRep t P m r) (CycRep t E m r) -> CycG t m r
cycPE = either Pow (CRT . Left)
{-# INLINABLE cycPE #-}

-- | Unwrap a 'CycG' as a 'CycRep' in powerful-basis representation.
unCycGPow :: (Fact m, CRTElt t r) => CycG t m r -> CycRep t P m r
{-# INLINABLE unCycGPow #-}
unCycGPow c = let (Pow u) = toPow' c in u

-- | Unwrap a 'CycG' as a 'CycRep' in decoding-basis representation.
unCycGDec :: (Fact m, CRTElt t r) => CycG t m r -> CycRep t D m r
{-# INLINABLE unCycGDec #-}
unCycGDec c = let (Dec u) = toDec' c in u

{-
-- | Unwrap a 'CycG' as a 'CycRep' in a CRT-basis representation.
uncycCRT :: (Fact m, CRTElt t r) => CycG t m r -> CycRepEC t m r
{-# INLINABLE uncycCRT #-}
uncycCRT c = let (CRT u) = toCRT' c in u
-}

-- | Extract a 'CycRep', in a desired representation, from a 'Cyc'.
class UnCyc t r where
  unCycPow :: (Fact m) => Cyc t m r -> CycRep t P m r
  unCycDec :: (Fact m) => Cyc t m r -> CycRep t D m r

instance CRTElt t Double => UnCyc t Double where
  unCycPow = unCycGPow . unCycDbl
  unCycDec = unCycGDec . unCycDbl

instance CRTElt t Int64 => UnCyc t Int64 where
  unCycPow = unCycGPow . unCycI64
  unCycDec = unCycGDec . unCycI64

instance CRTElt t (ZqBasic q z) => UnCyc t (ZqBasic q z) where
  unCycPow = unCycGPow . unCycZqB
  unCycDec = unCycGDec . unCycZqB

-- not for Integer, because we can't convert between Pow and Dec reps

instance Tensor t (RRq q r) => UnCyc t (RRq q r) where
  unCycPow (PowRRq v) = v
  unCycPow (DecRRq v) = toPow v

  unCycDec (DecRRq v) = v
  unCycDec (PowRRq v) = toDec v

instance (UnCyc t a, UnCyc t b,
         IFunctor t, IFElt t a, IFElt t b, IFElt t (a,b))
  => UnCyc t (a,b) where
  unCycPow (CycPair a b) = zipWithI (,) (unCycPow a) (unCycPow b)
  unCycDec (CycPair a b) = zipWithI (,) (unCycDec a) (unCycDec b)

---------- Algebraic instances ----------

instance (Fact m, ZeroTestable r, CRTElt t r, ForallFact2 ZeroTestable.C t r)
  => ZeroTestable.C (CycG t m r) where
  isZero x = case x of
    (Pow u) -> isZero u
    (Dec u) -> isZero u
    (CRT (Right u)) -> isZero u
    c@(CRT _) -> isZero $ toPow' c
    (Scalar c) -> isZero c
    (Sub c) -> isZero c
    \\ (entailFact2 :: Fact m :- ZeroTestable.C (t m r))

deriving instance ZeroTestable (CycG t m Double) => ZeroTestable.C (Cyc t m Double)
deriving instance ZeroTestable (CycG t m Int64) => ZeroTestable.C (Cyc t m Int64)
deriving instance ZeroTestable (CycG t m (ZqBasic q z)) => ZeroTestable.C (Cyc t m (ZqBasic q z))

instance (ZeroTestable (Cyc t m a), ZeroTestable (Cyc t m b))
  => ZeroTestable.C (Cyc t m (a,b)) where
  isZero (CycPair a b) = isZero a && isZero b

instance ZeroTestable (t m Integer) => ZeroTestable.C (Cyc t m Integer) where
  isZero (PowIgr v) = isZero v
  isZero (DecIgr v) = isZero v

instance ZeroTestable (t m (RRq q r)) => ZeroTestable.C (Cyc t m (RRq q r)) where
  isZero (PowRRq c) = isZero c
  isZero (DecRRq c) = isZero c

-----

instance (Eq r, Fact m, CRTElt t r, ForallFact2 Eq t r) => Eq (CycG t m r) where
  {-# INLINABLE (==) #-}
  -- same representations
  (Scalar c1) == (Scalar c2) = c1 == c2
  (Pow u1) == (Pow u2) = u1 == u2 \\ (entailFact2 :: Fact m :- Eq (t m r))
  (Dec u1) == (Dec u2) = u1 == u2 \\ (entailFact2 :: Fact m :- Eq (t m r))
  (CRT (Right u1)) == (CRT (Right u2)) =
    u1 == u2 \\ (entailFact2 :: Fact m :- Eq (t m r))

  -- compare Subs in compositum
  -- EAC: would like to convert c2 to basis of c1 *before* embedding
  (Sub (c1 :: CycG t l1 r)) == (Sub (c2 :: CycG t l2 r)) =
    (embed' c1 :: CycG t (FLCM l1 l2) r) == embed' c2
    \\ lcmDivides (Proxy::Proxy l1) (Proxy::Proxy l2)

  -- some other relatively efficient comparisons
  (Scalar c1) == (Pow u2) = scalarPow c1 == u2
                            \\ (entailFact2 :: Fact m :- Eq (t m r))
  (Pow u1) == (Scalar c2) = u1 == scalarPow c2
                            \\ (entailFact2 :: Fact m :- Eq (t m r))

  -- otherwise: compare in powerful basis
  c1 == c2 = toPow' c1 == toPow' c2

deriving instance Eq (CycG t m Int64)         => Eq (Cyc t m Int64)
deriving instance Eq (CycG t m (ZqBasic q z)) => Eq (Cyc t m (ZqBasic q z))

instance (Eq (Cyc t m a), Eq (Cyc t m b)) => Eq (Cyc t m (a,b)) where
  (CycPair a b) == (CycPair a' b') = a == a' && b == b'

-- no Eq for Double or RRq due to precision, nor for Integer because
-- we can't change representations

instance (CRTElt t Int64, ForallFact2 Eq t Int64)
  => ForallFact2 Eq (Cyc t) Int64 where
  entailFact2 = C.Sub Dict

instance (Eq (ZqBasic q z), CRTElt t (ZqBasic q z),
          ForallFact2 Eq t (ZqBasic q z))
  => ForallFact2 Eq (Cyc t) (ZqBasic q z) where
  entailFact2 = C.Sub Dict

instance (ForallFact2 Eq (Cyc t) a, ForallFact2 Eq (Cyc t) b)
  => ForallFact2 Eq (Cyc t) (a,b) where
  entailFact2 :: forall m . Fact m :- Eq (Cyc t m (a,b))
  entailFact2 = C.Sub (Dict
                       \\ (entailFact2 :: Fact m :- Eq (Cyc t m a))
                       \\ (entailFact2 :: Fact m :- Eq (Cyc t m b)))

-----

instance (Fact m, CRTElt t r, ZeroTestable r) => Additive.C (CycG t m r) where
  {-# INLINABLE zero #-}
  zero = Scalar zero

  {-# INLINABLE (+) #-}
  -- optimized addition of zero
  (Scalar c1) + c2 | isZero c1 = c2
  c1 + (Scalar c2) | isZero c2 = c1

  -- SAME CONSTRUCTORS
  (Scalar c1) + (Scalar c2) = Scalar (c1+c2)
  (Pow u1) + (Pow u2) = Pow $ u1 + u2
  (Dec u1) + (Dec u2) = Dec $ u1 + u2
  (CRT u1) + (CRT u2) = CRT $ u1 + u2
  -- Sub plus Sub: work in compositum
  -- EAC: would like to convert c2 to basis of c1 before embedding
  (Sub (c1 :: CycG t m1 r)) + (Sub (c2 :: CycG t m2 r)) =
    (Sub $ (embed' c1 :: CycG t (FLCM m1 m2) r) + embed' c2)
    \\ lcm2Divides (Proxy::Proxy m1) (Proxy::Proxy m2) (Proxy::Proxy m)

  -- SCALAR PLUS SOMETHING ELSE

  (Scalar c)  + (Pow u)  = Pow $ scalarPow c + u
  (Scalar c)  + (Dec u)  = Pow $ scalarPow c + toPow u -- workaround scalarDec
  (Scalar c)  + (CRT u)  = CRT $ scalarCRT c + u
  (Scalar c1) + (Sub c2) = Sub $ Scalar c1 + c2 -- must re-wrap Scalar!

  (Pow u)  + (Scalar c)  = Pow $ u + scalarPow c
  (Dec u)  + (Scalar c)  = Pow $ toPow u + scalarPow c -- workaround scalarDec
  (CRT u)  + (Scalar c)  = CRT $ u + scalarCRT c
  (Sub c1) + (Scalar c2) = Sub $ c1 + Scalar c2

  -- SUB PLUS NON-SUB, NON-SCALAR: work in full ring
  -- EAC: would like to convert sub to basis of other before embedding
  (Sub c1) + c2 = embed' c1 + c2
  c1 + (Sub c2) = c1 + embed' c2

  -- mixed Dec and Pow: use linear-time conversions
  (Dec u1) + (Pow u2) = Pow $ toPow u1 + u2
  (Pow u1) + (Dec u2) = Pow $ u1 + toPow u2

  -- one CRT: convert other to CRT
  (CRT u1) + (Pow u2) = CRT $ u1 + toCRT u2
  (CRT u1) + (Dec u2) = CRT $ u1 + toCRT u2
  (Pow u1) + (CRT u2) = CRT $ toCRT u1 + u2
  (Dec u1) + (CRT u2) = CRT $ toCRT u1 + u2

  {-# INLINABLE negate #-}
  negate (Pow u) = Pow $ negate u
  negate (Dec u) = Dec $ negate u
  negate (CRT u) = CRT $ negate u
  negate (Scalar c) = Scalar (negate c)
  negate (Sub c) = Sub $ negate c

deriving instance Additive (CycG t m Double) => Additive.C (Cyc t m Double)
deriving instance Additive (CycG t m Int64) => Additive.C (Cyc t m Int64)
deriving instance Additive (CycG t m (ZqBasic q z)) => Additive.C (Cyc t m (ZqBasic q z))

-- no instance for Integer because we can't convert between reps

instance (Additive (Cyc t m a), Additive (Cyc t m b))
  => Additive.C (Cyc t m (a,b)) where
  zero = CycPair zero zero
  (CycPair a b) + (CycPair a' b') = CycPair (a+a') (b+b')
  negate (CycPair a b) = CycPair (negate a) (negate b)

instance (Additive (RRq q r), Tensor t (RRq q r), IFunctor t, Fact m)
  => Additive.C (Cyc t m (RRq q r)) where
  zero = PowRRq zero

  (PowRRq u1) + (PowRRq u2) = PowRRq $ u1 + u2
  (DecRRq u1) + (DecRRq u2) = DecRRq $ u1 + u2
  (PowRRq u1) + (DecRRq u2) = PowRRq $ u1 + toPow u2
  (DecRRq u1) + (PowRRq u2) = PowRRq $ toPow u1 + u2

  negate (PowRRq u) = PowRRq $ negate u
  negate (DecRRq u) = DecRRq $ negate u

-- ForallFact2 instances needed for RescaleCyc instance

instance (CRTElt t Int64) => ForallFact2 Additive.C (Cyc t) Int64 where
  entailFact2 = C.Sub Dict

instance (CRTElt t Double) => ForallFact2 Additive.C (Cyc t) Double where
  entailFact2 = C.Sub Dict

instance (CRTElt t (ZqBasic q z), ZeroTestable z)
  => ForallFact2 Additive.C (Cyc t) (ZqBasic q z) where
  entailFact2 = C.Sub Dict

instance (ForallFact2 Additive.C (Cyc t) a,
          ForallFact2 Additive.C (Cyc t) b)
  => ForallFact2 Additive.C (Cyc t) (a,b) where
  entailFact2 :: forall m . Fact m :- Additive.C (Cyc t m (a,b))
  entailFact2 = C.Sub (Dict
                       \\ (entailFact2 :: Fact m :- Additive.C (Cyc t m a))
                       \\ (entailFact2 :: Fact m :- Additive.C (Cyc t m b)))

-----

instance (Fact m, CRTElt t r, ZeroTestable r) => Ring.C (CycG t m r) where
  {-# INLINABLE one #-}
  one = Scalar one

  {-# INLINABLE fromInteger #-}
  fromInteger = Scalar . fromInteger

  {-# INLINABLE (*) #-}

  -- optimized mul-by-zero
  v1@(Scalar c1) * _ | isZero c1 = v1
  _ * v2@(Scalar c2) | isZero c2 = v2

  -- both CRT: if over C, then convert result to pow for precision reasons
  (CRT u1) * (CRT u2) = either (Pow . toPow) (CRT . Right) $ u1*u2

  -- at least one Scalar
  (Scalar c1) * (Scalar c2) = Scalar $ c1*c2
  (Scalar c) * (Pow u) = Pow $ c *> u
  (Scalar c) * (Dec u) = Dec $ c *> u
  (Scalar c) * (CRT u) = CRT $ c *> u
  (Scalar c1) * (Sub c2) = Sub $ Scalar c1 * c2

  (Pow u) * (Scalar c) = Pow $ c *> u
  (Dec u) * (Scalar c) = Dec $ c *> u
  (CRT u) * (Scalar c) = CRT $ c *> u
  (Sub c1) * (Scalar c2) = Sub $ c1 * Scalar c2

  -- TWO SUBS: work in a CRT rep for compositum
  (Sub (c1 :: CycG t m1 r)) * (Sub (c2 :: CycG t m2 r)) =
    -- re-wrap c1, c2 as Subs of the composition, and force them to CRT
    (Sub $ (toCRT' $ Sub c1 :: CycG t (FLCM m1 m2) r) * toCRT' (Sub c2))
    \\ lcm2Divides (Proxy::Proxy m1) (Proxy::Proxy m2) (Proxy::Proxy m)

  -- ELSE: work in appropriate CRT rep
  c1 * c2 = toCRT' c1 * toCRT' c2

deriving instance Ring (CycG t m Double)        => Ring.C (Cyc t m Double)
deriving instance Ring (CycG t m Int64)         => Ring.C (Cyc t m Int64)
deriving instance Ring (CycG t m (ZqBasic q z)) => Ring.C (Cyc t m (ZqBasic q z))

instance (Ring (Cyc t m a), Ring (Cyc t m b)) => Ring.C (Cyc t m (a,b)) where
  one = CycPair one one
  fromInteger z = CycPair (fromInteger z) (fromInteger z)
  (CycPair a b) * (CycPair a' b') = CycPair (a*a') (b*b')

-- no instance for RRq because it's not a ring

-- ForallFact2 instances in case they're useful

instance (CRTElt t Int64) => ForallFact2 Ring.C (Cyc t) Int64 where
  entailFact2 = C.Sub Dict

instance (CRTElt t Double) => ForallFact2 Ring.C (Cyc t) Double where
  entailFact2 = C.Sub Dict

instance (CRTElt t (ZqBasic q z), ZeroTestable z)
  => ForallFact2 Ring.C (Cyc t) (ZqBasic q z) where
  entailFact2 = C.Sub Dict

instance (ForallFact2 Ring.C (Cyc t) a,
          ForallFact2 Ring.C (Cyc t) b)
  => ForallFact2 Ring.C (Cyc t) (a,b) where
  entailFact2 :: forall m . Fact m :- Ring.C (Cyc t m (a,b))
  entailFact2 = C.Sub (Dict
                       \\ (entailFact2 :: Fact m :- Ring.C (Cyc t m a))
                       \\ (entailFact2 :: Fact m :- Ring.C (Cyc t m b)))

-----

instance (Fact m, CRTElt t r, ZeroTestable r) => Module.C r (CycG t m r) where
  r *> (Scalar c) = Scalar $ r * c
  r *> (Pow v)    = Pow $ r *> v
  r *> (Dec v)    = Dec $ r *> v
  r *> (Sub c)    = Sub $ r *> c
  r *> x          = r *> toPow' x

deriving instance Module Int64 (CycG t m Int64) => Module.C Int64 (Cyc t m Int64)
deriving instance Module Double (CycG t m Double) => Module.C Double (Cyc t m Double)
deriving instance (Module (ZqBasic q z) (CycG t m (ZqBasic q z)),
                   Ring (ZqBasic q z)) -- satisfy superclass
  => Module.C (ZqBasic q z) (Cyc t m (ZqBasic q z))

instance (Module a (Cyc t m a), Module b (Cyc t m b))
  => Module.C (a,b) (Cyc t m (a,b)) where
  (a,b) *> (CycPair ca cb) = CycPair (a *> ca) (b *> cb)

-- no instance for RRq because it's not, mathematically

-- ForallFact2 instances needed for special RescaleCyc instance

instance (CRTElt t Int64) => ForallFact2 (Module.C Int64) (Cyc t) Int64 where
  entailFact2 = C.Sub Dict

instance (CRTElt t Double) => ForallFact2 (Module.C Double) (Cyc t) Double where
  entailFact2 = C.Sub Dict

instance (CRTElt t (ZqBasic q z), ZeroTestable z)
  => ForallFact2 (Module.C (ZqBasic q z)) (Cyc t) (ZqBasic q z) where
  entailFact2 = C.Sub Dict

instance (ForallFact2 (Module.C a) (Cyc t) a,
          ForallFact2 (Module.C b) (Cyc t) b)
  => ForallFact2 (Module.C (a,b)) (Cyc t) (a,b) where
  entailFact2 :: forall m . Fact m :- Module.C (a,b) (Cyc t m (a,b))
  entailFact2 = C.Sub (Dict
                       \\ (entailFact2 :: Fact m :- Module.C a (Cyc t m a))
                       \\ (entailFact2 :: Fact m :- Module.C b (Cyc t m b)))

-- Module over finite field

-- | \(R_p\) is an \(\F_{p^d}\)-module when \(d\) divides
-- \(\varphi(m)\), by applying \(d\)-dimensional \(\F_p\)-linear
-- transform on \(d\)-dim chunks of powerful basis coeffs.
instance (GFCtx fp d, Fact m, CRTElt t fp, Module (GF fp d) (t m fp))
  => Module.C (GF fp d) (CycG t m fp) where
  -- CJP: optimize for Scalar if we can: r *> (Scalar c) is the tensor
  -- that has the coeffs of (r*c), followed by zeros.  (This assumes
  -- that the powerful basis has 1 as its first element, and that
  -- we're using pow to define the module mult.)

  -- Can use any r-basis to define module mult, but must be
  -- consistent. We use powerful basis.
  r *> (Pow v) = Pow $ r *> v
  r *> x = r *> toPow' x

deriving instance (Ring (GF (ZqBasic q z) d),
                   Module (GF (ZqBasic q z) d) (CycG t m (ZqBasic q z)))
  => Module.C (GF (ZqBasic q z) d) (Cyc t m (ZqBasic q z))

---------- Cyclotomic classes ----------

instance (CRTElt t r, ZeroTestable r, IntegralDomain r)
  => Cyclotomic (CycG t) r where
  scalarCyc = Scalar

  mulG (Pow u) = Pow $ R.mulGPow u
  mulG (Dec u) = Dec $ R.mulGDec u
  mulG (CRT (Left u)) = Pow $ R.mulGPow $ toPow u -- go to Pow for precision
  mulG (CRT (Right u)) = CRT $ Right $ R.mulGCRTC u
  mulG c@(Scalar _) = mulG $ toCRT' c
  mulG (Sub c) = mulG $ embed' c   -- must go to full ring

  divG (Pow u) = Pow <$> R.divGPow u
  divG (Dec u) = Dec <$> R.divGDec u
  divG (CRT (Left u)) = Pow <$> R.divGPow (toPow u) -- go to Pow for precision
  divG (CRT (Right u)) = Just $ (CRT . Right) $ R.divGCRTC u
  divG c@(Scalar _) = divG $ toCRT' c
  divG (Sub c) = divG $ embed' c  -- must go to full ring

  advisePow = toPow'
  adviseDec = toDec'
  adviseCRT = toCRT'

-- CJP: can't derive instances here because Cyc isn't the *last*
-- argument of the class

instance Cyclotomic (CycG t) Double => Cyclotomic (Cyc t) Double where
  scalarCyc = CycDbl . scalarCyc
  mulG      = CycDbl . mulG      . unCycDbl
  divG      = fmap CycDbl . divG . unCycDbl
  advisePow = CycDbl . advisePow . unCycDbl
  adviseDec = CycDbl . adviseDec . unCycDbl
  adviseCRT = CycDbl . adviseCRT . unCycDbl

instance Cyclotomic (CycG t) Int64 => Cyclotomic (Cyc t) Int64 where
  scalarCyc = CycI64 . scalarCyc
  mulG      = CycI64 . mulG      . unCycI64
  divG      = fmap CycI64 . divG . unCycI64
  advisePow = CycI64 . advisePow . unCycI64
  adviseDec = CycI64 . adviseDec . unCycI64
  adviseCRT = CycI64 . adviseCRT . unCycI64

instance Cyclotomic (CycG t) (ZqBasic q z) => Cyclotomic (Cyc t) (ZqBasic q z) where
  scalarCyc = CycZqB . scalarCyc
  mulG      = CycZqB . mulG      . unCycZqB
  divG      = fmap CycZqB . divG . unCycZqB
  advisePow = CycZqB . advisePow . unCycZqB
  adviseDec = CycZqB . adviseDec . unCycZqB
  adviseCRT = CycZqB . adviseCRT . unCycZqB

instance (Cyclotomic (Cyc t) a, Cyclotomic (Cyc t) b)
  => Cyclotomic (Cyc t) (a,b) where
  scalarCyc (a,b) = CycPair (scalarCyc a) (scalarCyc b)
  mulG (CycPair a b) = CycPair (mulG a) (mulG b)
  divG (CycPair a b) = CycPair <$> divG a <*> divG b
  advisePow (CycPair a b) = CycPair (advisePow a) (advisePow b)
  adviseDec (CycPair a b) = CycPair (adviseDec a) (adviseDec b)
  adviseCRT (CycPair a b) = CycPair (adviseCRT a) (adviseCRT b)

instance (Tensor t (RRq q r)) => Cyclotomic (Cyc t) (RRq q r) where
  scalarCyc = PowRRq . scalarPow
  mulG (PowRRq c) = PowRRq $ mulGPow c
  mulG (DecRRq c) = DecRRq $ mulGDec c
  divG (PowRRq c) = PowRRq <$> divGPow c
  divG (DecRRq c) = DecRRq <$> divGDec c
  advisePow (DecRRq c) = PowRRq $ toPow c
  advisePow c = c
  adviseDec (PowRRq c) = DecRRq $ toDec c
  adviseDec c = c
  adviseCRT = id

-----

instance (GSqNorm (CycG t) Double) => GSqNorm (Cyc t) Double where
  gSqNorm = gSqNorm . unCycDbl

instance (GSqNorm (CycG t) Int64) => GSqNorm (Cyc t) Int64 where
  gSqNorm = gSqNorm . unCycI64

-----

instance TensorGaussian t q => GaussianCyc (CycG t) q where
  tweakedGaussian = fmap Dec . R.tweakedGaussian

instance GaussianCyc (CycG t) Double => GaussianCyc (Cyc t) Double where
  tweakedGaussian = fmap CycDbl . L.tweakedGaussian

-- CJP: no GaussianCyc for Int64, Integer, ZqBasic, pairs, or RRq

-- | uses 'Double' precision for the intermediate Gaussian samples
instance (TensorGaussian t Double, IFElt t Double, IFunctor t, ToInteger z, IFElt t z)
  => RoundedGaussianCyc (CycG t) z where
  {-# INLINABLE roundedGaussian #-}
  roundedGaussian = fmap Dec . R.roundedGaussian

-- | uses 'Double' precision for the intermediate Gaussian samples
instance RoundedGaussianCyc (CycG t) Int64 => RoundedGaussianCyc (Cyc t) Int64 where
  roundedGaussian = fmap CycI64 . L.roundedGaussian

-- CJP: no RoundedGaussianCyc for Integer, Double, ZqBasic, or pairs

-- | uses 'Double' precision for the intermediate Gaussian samples
instance (TensorGaussian t Double, IFElt t Double, IFunctor t, Mod zp,
          Lift zp (ModRep zp), CRTElt t zp, IFElt t (LiftOf zp))
  => CosetGaussianCyc (CycG t) zp where
  {-# INLINABLE cosetGaussian #-}
  cosetGaussian v = (Dec <$>) . R.cosetGaussian v . unCycGDec

-- | uses 'Double' precision for the intermediate Gaussian samples
instance (CosetGaussianCyc (CycG t) (ZqBasic q Int64))
  => CosetGaussianCyc (Cyc t) (ZqBasic q Int64) where
  cosetGaussian v = fmap CycI64 . L.cosetGaussian v . unCycZqB

-- CJP: no CosetGaussianCyc for Double, Int64, Integer, or pairs

-----

instance (CRTElt t r, ZeroTestable r, IntegralDomain r) -- ZT, ID for superclass
  => ExtensionCyc (CycG t) r where

  -- lazily embed
  embed :: forall t m m' r . (m `Divides` m')
            => CycG t m r -> CycG t m' r
  embed (Scalar c) = Scalar c           -- keep as scalar
  embed (Sub (c :: CycG t l r)) = Sub c -- keep as subring element
    \\ transDivides (Proxy::Proxy l) (Proxy::Proxy m) (Proxy::Proxy m')
  embed c = Sub c

  twace :: forall t m m' r .
          (CRTElt t r, ZeroTestable r, IntegralDomain r, m `Divides` m')
       => CycG t m' r -> CycG t m r
  twace (Pow u) = Pow $ twacePow u
  twace (Dec u) = Dec $ twaceDec u
  twace (CRT u) = either (cycPE . twaceCRTE) (cycPC . twaceCRTC) u
  twace (Scalar u) = Scalar u
  twace (Sub (c :: CycG t l r)) = Sub (twace c :: CycG t (FGCD l m) r)
                                  \\ gcdDivides (Proxy::Proxy l) (Proxy::Proxy m)

  powBasis = (Pow <$>) <$> R.powBasis

  coeffsCyc L.Pow c' = Pow <$> R.coeffsPow (unCycGPow c')
  coeffsCyc L.Dec c' = Dec <$> R.coeffsDec (unCycGDec c')

instance ExtensionCyc (CycG t) Double => ExtensionCyc (Cyc t) Double where
  embed = CycDbl . embed . unCycDbl
  twace = CycDbl . twace . unCycDbl
  powBasis = (CycDbl <$>) <$> powBasis
  coeffsCyc b = fmap CycDbl . coeffsCyc b . unCycDbl

instance ExtensionCyc (CycG t) Int64 => ExtensionCyc (Cyc t) Int64 where
  embed = CycI64 . embed . unCycI64
  twace = CycI64 . twace . unCycI64
  powBasis = (CycI64 <$>) <$> powBasis
  coeffsCyc b = fmap CycI64 . coeffsCyc b . unCycI64

instance ExtensionCyc (CycG t) (ZqBasic q z) => ExtensionCyc (Cyc t) (ZqBasic q z) where
  embed = CycZqB . embed . unCycZqB
  twace = CycZqB . twace . unCycZqB
  powBasis = (CycZqB <$>) <$> powBasis
  coeffsCyc b = fmap CycZqB . coeffsCyc b . unCycZqB

instance (ExtensionCyc (Cyc t) a, ExtensionCyc (Cyc t) b)
  => ExtensionCyc (Cyc t) (a,b) where
  embed (CycPair a b) = CycPair (embed a) (embed b)
  twace (CycPair a b) = CycPair (twace a) (twace b)
  powBasis = zipWith CycPair <$> powBasis <*> powBasis
  coeffsCyc bas (CycPair a b) =
    zipWith CycPair (coeffsCyc bas a) (coeffsCyc bas b)

instance (Tensor t (RRq q r)) => ExtensionCyc (Cyc t) (RRq q r) where
  embed (PowRRq u) = PowRRq $ embedPow u
  embed (DecRRq u) = DecRRq $ embedDec u
  twace (PowRRq u) = PowRRq $ twacePow u
  twace (DecRRq u) = DecRRq $ twaceDec u
  powBasis = (PowRRq <$>) <$> R.powBasis
  coeffsCyc L.Pow (PowRRq c) = PowRRq <$> R.coeffsPow c
  coeffsCyc L.Dec (DecRRq c) = DecRRq <$> R.coeffsDec c
  coeffsCyc L.Pow (DecRRq c) = PowRRq <$> R.coeffsPow (toPow c)
  coeffsCyc L.Dec (PowRRq c) = DecRRq <$> R.coeffsDec (toDec c)

-- | Force to a non-'Sub' constructor (for internal use only).
embed' :: forall t r l m . (l `Divides` m, CRTElt t r)
       => CycG t l r -> CycG t m r
{-# INLINE embed' #-}
embed' (Pow u) = Pow $ embedPow u
embed' (Dec u) = Dec $ embedDec u
embed' (CRT u) = either (cycPE . embedCRTE) (cycPC . embedCRTC) u
embed' (Scalar c) = Scalar c
embed' (Sub (c :: CycG t k r)) = embed' c
  \\ transDivides (Proxy::Proxy k) (Proxy::Proxy l) (Proxy::Proxy m)

-----

instance (ZPP r, CRTElt t r, TensorCRTSet t (ZpOf r), ExtensionCyc (CycG t) r)
  => CRTSetCyc (CycG t) r where
  crtSet = (Pow <$>) <$> R.crtSet
  {-# INLINABLE crtSet #-}

instance (CRTSetCyc (CycG t) (ZqBasic q z))
  => CRTSetCyc (Cyc t) (ZqBasic q z) where
  crtSet = (CycZqB <$>) <$> crtSet

-- CJP TODO?: instance CRTSetCyc (Cyc t) (a,b)

-----

type instance LiftOf (CycG t m r) = CycG t m (LiftOf r)
type instance LiftOf (Cyc  t m r) = Cyc  t m (LiftOf r)

instance (Lift b a, CRTElt t b, Tensor t a) => LiftCyc (CycG t) b where
  liftCyc L.Pow (Pow u) = Pow $ lift u
  liftCyc L.Pow (Dec u) = Pow $ lift $ toPow u
  liftCyc L.Pow (CRT u) = Pow $ lift $ either toPow toPow u
  -- optimized for subrings; these are correct for powerful basis but
  -- not for decoding
  liftCyc L.Pow (Scalar c) = Scalar $ lift c
  liftCyc L.Pow (Sub c) = Sub $ liftCyc L.Pow c

  liftCyc L.Dec c = Dec $ lift $ unCycGDec c

instance (LiftCyc (CycG t) (ZqBasic q Int64))
  => LiftCyc (Cyc t) (ZqBasic q Int64) where
  liftCyc b = CycI64 . liftCyc b . unCycZqB

-- specialized to Double so we know the target base type
instance (Lift' (RRq q Double), Tensor t (RRq q Double), Tensor t Double)
  => LiftCyc (Cyc t) (RRq q Double) where
  liftCyc L.Pow (PowRRq u) = CycDbl $ Pow $ lift u
  liftCyc L.Dec (DecRRq u) = CycDbl $ Dec $ lift u
  liftCyc L.Dec (PowRRq u) = CycDbl $ Dec $ lift $ toDec u
  liftCyc L.Pow (DecRRq u) = CycDbl $ Pow $ lift $ toPow u

instance (UnCyc t (a,b), Lift (a,b) Integer, ForallFact1 Applicative t)
  => LiftCyc (Cyc t) (a,b) where
  liftCyc L.Pow = PowIgr . fmap lift . unCycPow
  liftCyc L.Dec = DecIgr . fmap lift . unCycDec

---------- Promoted lattice operations ----------

-- | promoted from base ring
instance (Reduce a b, CRTElt t a, CRTElt t b) => ReduceCyc (CycG t) a b where
  reduceCyc (Pow u)    = Pow    $ reduce u
  reduceCyc (Dec u)    = Dec    $ reduce u
  reduceCyc (CRT u)    = Pow    $ reduce $ either toPow toPow u
  reduceCyc (Scalar c) = Scalar $ reduce c
  reduceCyc (Sub c)    = Sub (reduceCyc c)

instance ReduceCyc (CycG t) Int64 (ZqBasic q Int64)
  => ReduceCyc (Cyc t) Int64 (ZqBasic q Int64) where
  reduceCyc = CycZqB . reduceCyc . unCycI64

instance (ReduceCyc (Cyc t) r a, ReduceCyc (Cyc t) r b)
  => ReduceCyc (Cyc t) r (a,b) where
  reduceCyc r = CycPair (reduceCyc r) (reduceCyc r)

instance (ReduceCyc (Cyc t) a b, Fact m,
          Additive (Cyc t m a), Additive (Cyc t m b)) -- Reduce superclasses
  => Reduce (Cyc t m a) (Cyc t m b) where
  reduce = reduceCyc

-- specialized to Double so we know the source base type
instance (Reduce Double (RRq q Double), CRTElt t Double, Tensor t (RRq q Double))
  => ReduceCyc (Cyc t) Double (RRq q Double) where
  reduceCyc (CycDbl (Pow u)) = PowRRq $ reduce u
  reduceCyc (CycDbl (Dec u)) = DecRRq $ reduce u
  reduceCyc (CycDbl c)       = reduceCyc $ CycDbl $ toPow' c

instance (Reduce Integer (ZqBasic q z), ForallFact1 Applicative t)
  => ReduceCyc (Cyc t) Integer (ZqBasic q z) where
  reduceCyc (PowIgr u) = CycZqB $ Pow $ reduce <$> u
  reduceCyc (DecIgr u) = CycZqB $ Dec $ reduce <$> u

-----

-- | Rescales relative to the powerful basis. This instance is
-- provided for convenience, but usage of 'RescaleCyc' is preferred.
instance (RescaleCyc (Cyc t) a b, Fact m,
          Additive (Cyc t m a), Additive (Cyc t m b)) -- superclasses
 => Rescale (Cyc t m a) (Cyc t m b) where
  rescale = rescaleCyc L.Pow

-- CJP: can we avoid incoherent instances by changing instance heads
-- and using overlapping instances with isomorphism constraints?

instance {-# INCOHERENT #-} (Rescale a b, CRTElt t a, Tensor t b)
  => RescaleCyc (CycG t) a b where
  -- Optimized for subring constructors, for powerful basis.
  -- Analogs for decoding basis are not quite correct, because (* -1)
  -- doesn't commute with 'rescale' due to tiebreakers!
  rescaleCyc L.Pow (Scalar c) = Scalar $ rescale c
  rescaleCyc L.Pow (Sub c) = Sub $ rescalePow c

  rescaleCyc L.Pow c = Pow $ fmapI rescale $ unCycGPow c
  rescaleCyc L.Dec c = Dec $ fmapI rescale $ unCycGDec c
  {-# INLINABLE rescaleCyc #-}

instance RescaleCyc (CycG t) a a where
  -- No-op rescale
  rescaleCyc _ = id
  {-# INLINABLE rescaleCyc #-}

instance (RescaleCyc (CycG t) (ZqBasic q z) (ZqBasic p z))
  => RescaleCyc (Cyc t) (ZqBasic q z) (ZqBasic p z) where
  rescaleCyc b = CycZqB . rescaleCyc b . unCycZqB

instance (Rescale (RRq q r) (RRq p r), Tensor t (RRq q r), Tensor t (RRq p r))
  => RescaleCyc (Cyc t) (RRq q r) (RRq p r) where
  rescaleCyc L.Pow (PowRRq u) = PowRRq $ rescale u
  rescaleCyc L.Pow (DecRRq u) = PowRRq $ rescale $ toPow u
  rescaleCyc L.Dec (DecRRq u) = DecRRq $ rescale u
  rescaleCyc L.Dec (PowRRq u) = DecRRq $ rescale $ toDec u

-- | specialized instance for product rings of \(\Z_q\)s
instance (LiftCyc (Cyc t) (ZqBasic q z), ReduceCyc (Cyc t) z b,
          Reflects q z, Reduce z b, Field b,
          ForallFact2 Additive.C (Cyc t) b, ForallFact2 (Module.C b) (Cyc t) b)
  => RescaleCyc (Cyc t) (ZqBasic q z, b) b where

  -- bring m into scope
  rescaleCyc :: forall m . Fact m
    => Basis -> Cyc t m (ZqBasic q z, b) -> Cyc t m b
  rescaleCyc bas (CycPair a b) =
    let qval :: z = proxy value (Proxy::Proxy q)
        z = liftCyc bas a
    in recip (reduce qval :: b) *> (b - reduceCyc z)
       \\ (entailFact2 :: Fact m :- Module.C b (Cyc t m b))
       \\ (entailFact2 :: Fact m :- Additive.C (Cyc t m b))

-- CJP: do we really need these? Just have client call rescaleCyc
-- multiple times?

instance (RescaleCyc (Cyc t) (b,c) c, RescaleCyc (Cyc t) (a,(b,c)) (b,c))
         => RescaleCyc (Cyc t) (a,(b,c)) c where

  rescaleCyc bas a = rescaleCyc bas (rescaleCyc bas a :: Cyc t _ (b,c))
  {-# INLINABLE rescaleCyc #-}

instance (RescaleCyc (Cyc t) (b,(c,d)) d,
          RescaleCyc (Cyc t) (a,(b,(c,d))) (b,(c,d)))
         => RescaleCyc (Cyc t) (a,(b,(c,d))) d where

  rescaleCyc bas a = rescaleCyc bas (rescaleCyc bas a :: Cyc t _ (b,(c,d)))
  {-# INLINABLE rescaleCyc #-}

instance (RescaleCyc (Cyc t) (b,(c,(d,e))) e,
          RescaleCyc (Cyc t) (a,(b,(c,(d,e)))) (b,(c,(d,e))))
         => RescaleCyc (Cyc t) (a,(b,(c,(d,e)))) e where

  rescaleCyc bas a = rescaleCyc bas (rescaleCyc bas a :: Cyc t _ (b,(c,(d,e))))
  {-# INLINABLE rescaleCyc #-}

-----

-- | promoted from base ring
instance (Gadget gad (ZqBasic q z),
          -- satisfy Gadget's Ring superclass; remove if it goes away
          Fact m, CRTElt t (ZqBasic q z),
          ZeroTestable (ZqBasic q z), IntegralDomain (ZqBasic q z))
  => Gadget gad (CycG t m (ZqBasic q z)) where
  gadget = (Scalar <$>) <$> gadget
  {-# INLINABLE gadget #-}
  -- CJP: default 'encode' works because mul-by-Scalar is fast

deriving instance Gadget gad (CycG t m (ZqBasic q z))
  => Gadget gad (Cyc t m (ZqBasic q z))

instance (Gadget gad (Cyc t m a), Gadget gad (Cyc t m b))
  => Gadget gad (Cyc t m (a,b)) where
  gadget = (++) <$> (map (flip CycPair zero) <$> gadget)
                <*> (map (CycPair zero) <$> gadget)

-- ForallFact2 in case they're useful

instance (Gadget gad (ZqBasic q z),
          -- remove these if they go away from above
          CRTElt t (ZqBasic q z), ZeroTestable (ZqBasic q z),
          IntegralDomain (ZqBasic q z))
  => ForallFact2 (Gadget gad) (Cyc t) (ZqBasic q z) where
  entailFact2 = C.Sub Dict

instance (ForallFact2 (Gadget gad) (Cyc t) a,
          ForallFact2 (Gadget gad) (Cyc t) b)
  => ForallFact2 (Gadget gad) (Cyc t) (a,b) where
  -- bring m into scope
  entailFact2 :: forall m . Fact m :- Gadget gad (Cyc t m (a,b))
  entailFact2 = C.Sub (Dict
                       \\ (entailFact2 :: Fact m :- Gadget gad (Cyc t m a))
                       \\ (entailFact2 :: Fact m :- Gadget gad (Cyc t m b)))

-----

toZL :: Tagged s [a] -> TaggedT s ZipList a
toZL = coerce

fromZL :: TaggedT s ZipList a -> Tagged s [a]
fromZL = coerce

-- | promoted from base ring, using the powerful basis for best geometry
instance (Decompose gad (ZqBasic q z), CRTElt t (ZqBasic q z), Fact m,
          -- for satisfying Decompose's Gadget superclass
          ZeroTestable (ZqBasic q z), IntegralDomain (ZqBasic q z))
         => Decompose gad (CycG t m (ZqBasic q z)) where

  type DecompOf (CycG t m (ZqBasic q z)) = CycG t m z

  -- faster implementations: decompose directly in subring, which is
  -- correct because we decompose in powerful basis
  decompose (Scalar c) = (Scalar <$>) <$> decompose c
  decompose (Sub c) = (Sub <$>) <$> decompose c

  -- traverse: Traversable (CycRep t P m) and Applicative (Tagged gad ZL)
  decompose (Pow u) = fromZL $ Pow <$> traverse (toZL . decompose) u
  decompose c = decompose $ toPow' c

  {-# INLINABLE decompose #-}

-- specific to Int64 because we need to know constructor for lift type
instance (Decompose gad (CycG t m (ZqBasic q Int64)))
  => Decompose gad (Cyc t m (ZqBasic q Int64)) where

  type DecompOf (Cyc t m (ZqBasic q Int64)) = Cyc t m Int64
  decompose (CycZqB c) = (CycI64 <$>) <$> decompose c

instance (Decompose gad (Cyc t m a), Decompose gad (Cyc t m b),
         DecompOf (Cyc t m a) ~ DecompOf (Cyc t m b))
  => Decompose gad (Cyc t m (a,b)) where
  type DecompOf (Cyc t m (a,b)) = DecompOf (Cyc t m a)
  decompose (CycPair a b) = (++) <$> decompose a <*> decompose b

-- ForallFact2 in case they're useful

instance (Decompose gad (ZqBasic q Int64), CRTElt t (ZqBasic q Int64),
          -- copied from Decompose instance above
          IntegralDomain (ZqBasic q Int64))
  => ForallFact2 (Decompose gad) (Cyc t) (ZqBasic q Int64) where
  entailFact2 = C.Sub Dict

-- can't do ForallFact2 for pairs because we'll need equality
-- constraint for DecompOf (Cyc t m a) and (Cyc t m b), but m isn't in
-- scope.

-----

-- | promoted from base ring, using the decoding basis for best geometry
instance (Correct gad (ZqBasic q z), CRTElt t (ZqBasic q z), Fact m,
          -- satisfy Gadget superclass
          ZeroTestable (ZqBasic q z), IntegralDomain (ZqBasic q z),
          Traversable (CycRep t D m))
  => Correct gad (CycG t m (ZqBasic q z)) where
  -- sequence: Monad [] and Traversable (CycRep t D m)
  -- sequenceA: Applicative (CycRep t D m) and Traversable (TaggedT gad [])
  correct bs = Dec *** (Dec <$>) $
               second sequence $ fmap fst &&& fmap snd $ (correct . pasteT) <$>
               sequenceA (unCycGDec <$> peelT bs)
  {-# INLINABLE correct #-}

-- specific to Int64 due to LiftOf
deriving instance Correct gad (CycG t m (ZqBasic q Int64))
  => Correct gad (Cyc t m (ZqBasic q Int64))

-- TODO: instance Correct gad (Cyc t m (a,b)) where
-- seems hard; see Correct instance for pairs in Gadget.hs


-- no ForallFact2 instance due to Traversable (CycRep t D m)
-- constraint in Correct instance, but maybe that can be replaced

---------- Change of representation (internal use only) ----------

toPow', toDec', toCRT' :: (Fact m, CRTElt t r) => CycG t m r -> CycG t m r
{-# INLINABLE toPow' #-}
{-# INLINABLE toDec' #-}
{-# INLINABLE toCRT' #-}

-- | Force to powerful-basis representation (for internal use only).
toPow' c@(Pow _) = c
toPow' (Dec u) = Pow $ toPow u
toPow' (CRT u) = Pow $ either toPow toPow u
toPow' (Scalar c) = Pow $ scalarPow c
toPow' (Sub c) = toPow' $ embed' c

-- | Force to decoding-basis representation (for internal use only).
toDec' (Pow u) = Dec $ toDec u
toDec' c@(Dec _) = c
toDec' (CRT u) = Dec $ either toDec toDec u
toDec' (Scalar c) = Dec $ toDec $ scalarPow c
toDec' (Sub c) = toDec' $ embed' c

-- | Force to a CRT representation (for internal use only).
toCRT' (Pow u) = CRT $ toCRT u
toCRT' (Dec u) = CRT $ toCRT u
toCRT' c@(CRT _) = c
toCRT' (Scalar c) = CRT $ scalarCRT c
-- CJP: the following is the fastest algorithm for when both source
-- and target have the same CRTr/CRTe choice.  It is not the fastest
-- when the choices are different (it will do an unnecessary CRT if
-- input is non-CRT), but this is an unusual case.  Note: both calls
-- to toCRT' are necessary in general, because embed' may not preserve
-- CRT representation!
toCRT' (Sub c) = toCRT' $ embed' $ toCRT' c

---------- Utility instances ----------

instance (Fact m, ForallFact2 Random t r, CRTElt t r) => Random (CycG t m r) where
  random g = let (u,g') = random g
             in (either Pow (CRT . Right) u, g')
  {-# INLINABLE random #-}

  randomR _ = error "randomR non-sensical for CycG"

deriving instance Random (CycG t m Double)        => Random (Cyc t m Double)
deriving instance Random (CycG t m Int64)         => Random (Cyc t m Int64)
deriving instance Random (CycG t m (ZqBasic q z)) => Random (Cyc t m (ZqBasic q z))

instance (Random (Cyc t m a), Random (Cyc t m b)) => Random (Cyc t m (a,b)) where
  random g = let (a,g') = random g
                 (b,g'') = random g'
                 in (CycPair a b, g'')
  randomR _ = error "randomR non-sensical for Cyc"

instance (Fact m, ForallFact2 Random t Integer) => Random (Cyc t m Integer) where
  random g = let (u,g') = random g in (PowIgr u, g')
  randomR = error "randomR nonsensical for Cyc over Integer"

instance (Fact m, ForallFact2 Random t (RRq q r))
  => Random (Cyc t m (RRq q r)) where
  random g = let (u,g') = random g in (PowRRq u, g')
  randomR = error "randomR nonsensical for Cyc over (RRq q r)"

-----

instance (Fact m, ForallFact2 Show t r, ForallFact2 Show t (CRTExt r), Show r)
  => Show (CycG t m r) where
  show (Pow x) = "Cyc.Pow " ++ show x
  show (Dec x) = "Cyc.Dec " ++ show x
  show (CRT (Left x)) = "Cyc.CRT " ++ show x
  show (CRT (Right x)) = "Cyc.CRT " ++ show x
  show (Scalar x) = "Cyc.Scalar " ++ show x
  show (Sub x) = "Cyc.Sub " ++ show x

deriving instance Show (CycG t m Double)        => Show (Cyc t m Double)
deriving instance Show (CycG t m Int64)         => Show (Cyc t m Int64)
deriving instance Show (CycG t m (ZqBasic q z)) => Show (Cyc t m (ZqBasic q z))
deriving instance (Show (Cyc t m a), Show (Cyc t m b))
                  => Show (Cyc t m (a,b))

deriving instance (Fact m, ForallFact2 Show t Integer)   => Show (Cyc t m Integer)
deriving instance (Fact m, ForallFact2 Show t (RRq q r)) => Show (Cyc t m (RRq q r))

-----

instance (Fact m, NFData r,
          ForallFact2 NFData t r, ForallFact2 NFData t (CRTExt r))
         => NFData (CycG t m r) where
  rnf (Pow u) = rnf u
  rnf (Dec u) = rnf u
  rnf (CRT u) = rnf u
  rnf (Scalar u) = rnf u
  rnf (Sub c) = rnf c

deriving instance NFData (CycG t m Double)        => NFData (Cyc t m Double)
deriving instance NFData (CycG t m Int64)         => NFData (Cyc t m Int64)
deriving instance NFData (CycG t m (ZqBasic q z)) => NFData (Cyc t m (ZqBasic q z))

instance (NFData (Cyc t m a), NFData (Cyc t m b)) => NFData (Cyc t m (a,b)) where
  rnf (CycPair a b) = rnf a `seq` rnf b

instance (Fact m, ForallFact2 NFData t Integer) => NFData (Cyc t m Integer) where
  rnf (PowIgr u) = rnf u
  rnf (DecIgr u) = rnf u

instance (Fact m, ForallFact2 NFData t (RRq q r))
  => NFData (Cyc t m (RRq q r)) where
  rnf (PowRRq u) = rnf u
  rnf (DecRRq u) = rnf u

-----

instance (Fact m, CRTElt t r, Protoable (CycRep t D m r))
         => Protoable (CycG t m r) where

  type ProtoType (CycG t m r) = ProtoType (CycRep t D m r)
  toProto (Dec uc) = toProto uc
  toProto x = toProto $ toDec' x
  fromProto x = Dec <$> fromProto x

-- TODO: define Protoable instances for Cyc?
