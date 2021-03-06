# Tutorial

## Displaying static HTML

`[TODO]`

## Obtaining dynamic values

`[TODO]`

## Observing values and events

You can subscribe to event occurences or dynamic changes via `subscribeEvent_`,
`subscribeDyn_` and `subscribeWeakDyn_`.

```purescript
-- | Perform an IOSync action whenever an event occurs.
subscribeEvent_ :: MonadFRP m => (a -> IOSync Unit) -> Event a -> m Unit

-- | Perform an IOSync action with the current value of the dynamic, and later
-- | whenever it changes.
subscribeDyn_ :: MonadFRP m => (a -> IOSync Unit) -> Dynamic a -> m Unit

-- | Perform an IOSync action with the current value of the dynamic, and later
-- | whenever it changes.
subscribeWeakDyn_ :: MonadFRP m => (a -> IOSync Unit) -> WeakDynamic a -> m Unit
```

Specular uses
[`IOSync`](https://github.com/slamdata/purescript-io/blob/master/src/Control/Monad/IOSync.purs)
as its main effect monad, which is non-standard in the PureScript world. That's
not a big deal though, since we can always conver from `Eff` using:

```purescript
liftEff :: Eff e a -> IOSync a
```

For example, here's a handy snippet for logging a Dynamic value to the console:

```
-- Assuming: dyn :: Dynamic a, Show a

subscribeDyn_ (liftEff <<< logShow) dyn
```

## Dynamic text and attributes

Once you have a Dynamic:

```purescript
foo :: Dynamic String
```

you can display it somehow in the HTML document.

One way to influence a document is to have changing text:

```purescript
-- | Display a HTML text node whose text content will reflect the value of the
-- | dynamic.
dynText :: MonadWidget m => WeakDynamic String -> m Unit
```

(note: for various reasons you have to first convert it to a `WeakDynamic`
using: `weaken :: Dynamic a -> WeakDynamic a`)

Another way to consume a dynamic is to have dynamically changing attributes on
an element:

```purescript
-- | `elDynAttr tag attrs content` - Display a HTML element with dynamically changing attributes.
elDynAttr :: MonadWidget m => String -> WeakDynamic Attrs -> m a -> m a
```

Example:

```purescript
-- Assume we have:
enabledD :: WeakDynamic Boolean

-- This will make a button that will be disabled when `enabled` is false
elDynAttr "button"
  (map (\enabledD -> if enabled' then mempty else "disabled" := "disabled") enabledD)
  (text "This is a button")
```

## Dynamic structure

`[TODO]`
