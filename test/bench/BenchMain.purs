module BenchMain where

import Prelude

import Bench.Builder (builderTests)
import Bench.Primitives (dynamicTests, weakDynamicTests)
import Bench.Types (Tests)
import Benchmark (fnEff, runBench)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Console (CONSOLE, log)
import Control.Monad.IO.Effect (INFINITY)
import Control.Monad.ST (ST)
import Data.List.Lazy (replicateM)
import Data.Traversable (for)
import Data.Tuple (Tuple(Tuple))

main :: forall s. Eff (st :: ST s, console :: CONSOLE, infinity :: INFINITY) Unit
main = do
  exportBenchmark
  bench builderTests
  bench dynamicTests
  bench weakDynamicTests

bench :: forall s. Tests -> Eff (st :: ST s, console :: CONSOLE, infinity :: INFINITY) Unit
bench tests = do

  log "Warmup..."

  tests' <- for tests $ \(Tuple name setupFn) -> do
    fn <- setupFn
    void $ replicateM 100 fn
    pure (Tuple name fn)

  log "Benchmarking..."

  runBench $
    for tests' $ \(Tuple name fn) ->
      fnEff name fn

-- Something randomly breaks inside the benchmarking library when
-- `window.Benchmark` is not available. This function exports it.
foreign import exportBenchmark :: forall e. Eff e Unit
