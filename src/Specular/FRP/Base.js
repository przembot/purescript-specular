// Frame a ~ DelayedEffects -> Time -> IOSync Unit
// sequenceFrame_ :: Array (Frame Unit) -> Frame Unit
exports.sequenceFrame_ = function(xs) {
  return function(r1) {
    return function(r2) {
      return function sequenceFrame_eff() {
        for(var i = 0; i < xs.length; i++) {
          xs[i](r1)(r2)();
        }
      };
    };
  };
};


// oncePerFrame_ :: Frame Unit -> IOSync (Frame Unit)
// oncePerFrame_ action = do
//   ref <- newIORef Nothing
//   pure $ do
//     time <- framePull $ getTime
//     m_lastTime <- framePull $ pullReadIORef ref
//     case m_lastTime of
//       Just lastTime | lastTime == time ->
//         pure unit
//       _ -> do
//         frameWriteIORef ref (Just time)
//         action
exports.oncePerFrame_ = function(action) {
  return function() {
    var lastTime = null;
    return function(effects) {
      return function(time) {
        return function oncePerFrame_eff() {
          if(lastTime !== time) {
            lastTime = time;
            action(effects)(time)();
          }
        };
      };
    };
  };
};
