{-# LANGUAGE TypeFamilies      #-}

module Crypto.Alchemy.Interpreter.ShowCT where

import Crypto.Alchemy.Language.Lam
import Crypto.Alchemy.Language.Lit
import Crypto.Alchemy.Language.CT
import Crypto.Lol (Cyc)
import Crypto.Lol.Applications.SymmSHE (CT)

data ShowCT (a :: *) = SCT {bindID::Int, unSCT::String}

instance SymCT ShowCT where

  type AdditiveCtxCT  ShowCT a = ()
  type RingCtxCT      ShowCT a = ()
  type ModSwitchCtxCT ShowCT a zp' = ()
  type RescaleCtxCT   ShowCT a zq' = ()
  type AddPubCtxCT    ShowCT (CT m zp (Cyc t m' zq)) = (Show (Cyc t m zp))
  type MulPubCtxCT    ShowCT (CT m zp (Cyc t m' zq)) = (Show (Cyc t m zp))
  type KeySwitchCtxCT ShowCT a zq' gad = ()
  type TunnelCtxCT    ShowCT t e r s e' r' s' zp zq gad = ()

  (SCT _ a) +^ (SCT _ b) = SCT 0 $ "( " ++ a ++ " )" ++ " + " ++ "( " ++ b ++ " )"
  (SCT _ a) *^ (SCT _ b) = SCT 0 $ "( " ++ a ++ " )" ++ " * " ++ "( " ++ b ++ " )"
  negCT (SCT _ a) = SCT 0 $ "-( " ++ a ++ " )"
  modSwitchPT (SCT _ a) = SCT 0 $ "modSwitch $ " ++ a
  rescaleCT (SCT _ a) = SCT 0 $ "rescale $ " ++ a
  addPublicCT a (SCT _ b) = SCT 0 $ "( " ++ show a ++ " )" ++ " + " ++ "( " ++ b ++ " )"
  mulPublicCT a (SCT _ b) = SCT 0 $ "( " ++ show a ++ " )" ++ " * " ++ "( " ++ b ++ " )"
  keySwitchQuadCT _ (SCT _ a) = SCT 0 $ "keySwitch <HINT> $ " ++ a
  tunnelCT _ (SCT _ a) = SCT 0 $ "tunnel <FUNC> $ " ++ a

instance Lambda ShowCT where
  lam f =
    -- EAC: use laziness!
    let (SCT i b) = f $ SCT i ("x" ++ show i)
    in SCT (i+1) $ "\\x" ++ show i ++ " -> " ++ b
  app (SCT i f) (SCT _ a) = SCT i $ "( " ++ f ++ " ) " ++ a

instance Lit ShowCT where
  type LitCtx ShowCT a = (Show a)
  lit a = SCT 0 $ show a