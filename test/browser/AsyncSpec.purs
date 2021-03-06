-- NB: this module is in browser tests, not node tests, because `asyncRequest`
-- requires MonadWidget. This should change in the future.
module AsyncSpec where

import Prelude hiding (append)

import BuilderSpec (newDynamic)
import Control.Monad.Aff.AVar (makeEmptyVar, putVar, takeVar)
import Control.Monad.Aff.Class (liftAff)
import Control.Monad.Cleanup (runCleanupT)
import Control.Monad.IO (IO)
import Control.Monad.IOSync.Class (liftIOSync)
import Specular.Internal.Effect (newRef)
import Data.Maybe (Maybe(..))
import Data.Tuple (Tuple(..), fst, snd)
import Specular.FRP (current, newEvent, pull, subscribeEvent_)
import Specular.FRP.Async (RequestState(..), asyncRequestMaybe, performEvent)
import Specular.FRP.Base (readBehavior, subscribeDyn_)
import Test.Spec (Spec, describe, it)
import Test.Spec.Runner (RunnerEffects)
import Test.Utils (append, clear, ioSync, shouldHaveValue, shouldReturn, yieldAff)
import Test.Utils.Dom (runBuilderInDiv)

spec :: forall eff. Spec (RunnerEffects eff) Unit
spec = do
  describe "asyncRequestMaybe" $ do
    it "makes a request for initial value" $ do
      avar <- makeEmptyVar
      log <- ioSync $ newRef []

      let request = liftAff $ takeVar avar

      _ <- runBuilderInDiv $ do
        result <- asyncRequestMaybe $ pure $ Just request
        subscribeDyn_ (append log) result

      log `shouldHaveValue` [Loading]

      clear log
      putVar "result" avar
      yieldAff
      log `shouldHaveValue` [Loaded "result"]

    it "makes a request when the value changes" $ do
      avar <- makeEmptyVar
      log <- ioSync $ newRef []

      let request = liftAff $ takeVar avar

      Tuple dyn setDyn <- ioSync $ newDynamic Nothing

      _ <- runBuilderInDiv $ do
        result <- asyncRequestMaybe dyn
        subscribeDyn_ (append log) result

      log `shouldHaveValue` [NotRequested]

      clear log
      ioSync $ setDyn (Just request)
      log `shouldHaveValue` [Loading]

      clear log
      putVar "result" avar
      yieldAff
      log `shouldHaveValue` [Loaded "result"]

    it "ignores responses to requests older than the current" $ do
      avar1 <- makeEmptyVar
      avar2 <- makeEmptyVar
      log <- ioSync $ newRef []

      Tuple dyn setDyn <- ioSync $ newDynamic Nothing

      _ <- runBuilderInDiv $ do
        result <- asyncRequestMaybe dyn
        subscribeDyn_ (append log) result

      log `shouldHaveValue` [NotRequested]

      clear log
      ioSync $ setDyn $ Just $ liftAff $ takeVar avar1
      ioSync $ setDyn $ Just $ liftAff $ takeVar avar2
      log `shouldHaveValue` [Loading, Loading]

      clear log
      putVar "result1" avar1
      log `shouldHaveValue` [] -- should be ignored, as new request is going on

      clear log
      putVar "result2" avar2
      yieldAff
      log `shouldHaveValue` [Loaded "result2"]

    it "ignores out-of-order responses" $ do
      avar1 <- makeEmptyVar
      avar2 <- makeEmptyVar
      log <- ioSync $ newRef []

      Tuple dyn setDyn <- ioSync $ newDynamic Nothing

      _ <- runBuilderInDiv $ do
        result <- asyncRequestMaybe dyn
        subscribeDyn_ (append log) result

      ioSync $ setDyn $ Just $ liftAff $ takeVar avar1
      ioSync $ setDyn $ Just $ liftAff $ takeVar avar2

      clear log
      putVar "result2" avar2
      yieldAff
      log `shouldHaveValue` [Loaded "result2"]

      clear log
      putVar "result1" avar1
      log `shouldHaveValue` [] -- should be ignored, as this request was replaced by avar2

    it "request dynamic and status dynamic are consistent" $ do
      -- `do status <- asyncRequestMaybe request`
      -- Some relations must hold between the values of `status` and `request`:
      --
      -- - If `request == Nothing`, then `status == NotRequested`
      -- - If `request` is `Just x`, then `status` is either `Loading` or `Loaded y`,
      --   where `y` is the result of running `x`.
      --
      -- A naive implementation would expose intermediate states where these
      -- invariants don't hold. This test checks for this.

      avar <- makeEmptyVar

      -- In `dyn` we'll store pairs of (String, IO String).
      -- The first string is a description, and goes to the log;
      -- the action is the request.
      Tuple dyn setDyn <- ioSync $ newDynamic $ Tuple "Nothing" (Nothing :: Maybe (IO String))

      let readDyn = ioSync <<< pull <<< readBehavior <<< current

      -- In `log` we'll have pairs of (String, String)
      -- The first String is the request description, the second is the result.
      log <- ioSync $ newRef []

      Tuple _ result <- runBuilderInDiv $ do
        status <- asyncRequestMaybe $ map snd dyn
        let result = Tuple <$> map fst dyn <*> status
        subscribeDyn_ (append log) $ result
        pure result

      log `shouldHaveValue` [Tuple "Nothing" NotRequested]
      readDyn result `shouldReturn` Tuple "Nothing" NotRequested

      -- Test with immediately executed action
      clear log
      ioSync $ setDyn $ Tuple "pure A" $ Just $ pure "A"
      yieldAff
      log `shouldHaveValue` [Tuple "pure A" Loading, Tuple "pure A" (Loaded "A")]
      readDyn result `shouldReturn` Tuple "pure A" (Loaded "A")

      -- Test with asynchronous action
      clear log
      ioSync $ setDyn $ Tuple "async B" $ Just $ liftAff $ takeVar avar
      log `shouldHaveValue` [Tuple "async B" Loading]
      readDyn result `shouldReturn` Tuple "async B" Loading

      clear log
      putVar "B" avar
      yieldAff
      log `shouldHaveValue` [Tuple "async B" (Loaded "B")]
      readDyn result `shouldReturn` Tuple "async B" (Loaded "B")

      -- Test with change to Nothing
      clear log
      ioSync $ setDyn $ Tuple "Nothing again" Nothing
      log `shouldHaveValue` [Tuple "Nothing again" NotRequested]
      readDyn result `shouldReturn` Tuple "Nothing again" NotRequested

  describe "performEvent" $ do
    it "runs handler and pushes return value to event" $ do
      {event,fire} <- ioSync newEvent
      log <- ioSync $ newRef []
      _ <- ioSync $ runCleanupT $ do
        result <- performEvent $ map
          (\x -> liftIOSync (append log ("handler:" <> x)) *> pure x)
          event
        subscribeEvent_ (\x -> append log $ "result:" <> x) result

      ioSync $ fire "A"
      ioSync $ fire "B"

      log `shouldHaveValue` ["handler:A", "result:A", "handler:B", "result:B"]

{-
Note [yieldAff]
~~~~~~~~~~~~~~~

The calls to `yieldAff` above are workarounds for the workaround for issue #10 -
see implementation of `asyncRequestMaybe`. It causes the propagation of
immediate results to be delivered on next tick, so we must also delay
inspecting results.
-}
