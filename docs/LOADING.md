# Session preparation

The optional **Flux Loading Screen** plugin (`plugins/flux_loading`) prepares local content after GMod downloads and mounts the server's content, before character selection. Admins can toggle **Flux Loading Screen** (`flux_loading`) under **Config â†’ Plugins**. Disabling opens character selection directly and releases any menu already waiting behind preparation. The native plugin manager persists the choice. Restart/reconnect after installation, or when enabling a plugin that was disabled at startup. See [the plugin instructions](../plugins/flux_loading/README.md).

This is an in-game Lua screen; it does not require a website or replace the engine's download screen. The optional HTML page under `loading/` remains separate and uses `sv_loadingurl`.

## Asset discovery

The initial queue reads the public Helix faction, class, item and loaded-character registries, projected DarkRP jobs and purchase catalogs (entities, shipments, vehicles, food and ammo), registered weapons/entities/vehicles and current scene models. String models, model lists and Helix model/skin/bodygroup tuples are supported. Models are deduplicated by normalized path. Temporary clientside model entities load model data and discover their materials; each entity is removed, including when discovery fails. Associated materials and registered item icons are then loaded through `Material`.

This uses mounted content and declared models. It does not crawl every installed Workshop file or infer models hidden inside arbitrary addon functions. Later dynamic spawns and shader/driver work may still cost time on first use. The engine's own [`util.PrecacheModel`](https://wiki.facepunch.com/gmod/util.PrecacheModel) does nothing on the client, so it is not used as a substitute for actual client preparation.

## Configuration

The custom Flux screen uses four SCP: Containment Breach images. It uses aspect-preserving full-screen crops, a dark overlay and a thin progress line. The screen displays the SCP backgrounds, a compact bottom-left status/progress area and recovery controls when needed. Branding, map names, taglines, large headings, model filenames and photo metadata are omitted. The slideshow defaults to 10 seconds per photo with a 1.5-second crossfade. Reduced motion switches photos without animation. It never adds an artificial delay to preparation.

`slideshow.enabled`, `interval`, `fade` and `slides` are editable in the same configuration. One local photo is decoded per slideshow step; the next is prepared shortly before switching. Missing or invalid decorative photos are skipped once and do not block character selection. Empty/disabled lists retain the dark fallback. No render targets, animated camera movements, blur or post-processing are allocated for the images.

Images ship under `flux/content/materials/flux/loading/`, and the server registers their virtual `materials/flux/loading/*.jpg` paths for normal client downloads. Include this content directory when updating. Normal client download/Workshop/FastDL settings still apply; remote delivery has not been live-tested in this revision. Attribution, source links and licenses remain in the bundled documentation and shared image metadata. See [image attribution and hashes](LOADING_IMAGES.md).

Edit `flux/config/sh_loading.lua` and restart/reconnect. Preparation is enabled by default. Settings control scene collection, model/material caps, batch sizes, per-frame time target, asset timeout and server-data timeout.

The default scheduler starts at most one model and six materials per frame with a 3 ms target. It checks the deadline before each operation; a single synchronous engine load cannot be interrupted, so this is not a hard frame-time guarantee. Default caps are 1,024 models and 4,096 materials. Caps and failures are reported rather than silently marked successful.

For assets declared dynamically or outside the supported registries, add mounted paths:

```lua
additionalModels = { "models/my_server/custom_player.mdl" },
additionalMaterials = { "my_server/ui/emblem.png" },
```

Material paths are relative to `materials/`; `.vmt`, PNG and JPG paths are accepted. This configuration does not download content. Use the normal server Workshop/FastDL setup to distribute it first.

## Generic extension hook

Plugins can contribute client assets through one public hook:

```lua
hook.Add("FluxCollectLoadingAssets", "MyContent.Loading", function(queue)
    queue:AddModel("models/my_content/terminal.mdl")
    queue:AddModels({ "models/my_content/chair.mdl" })
    queue:AddMaterial("my_content/ui/terminal.png")
end)
```

Contributors should add paths and return nothing. There are no addon-name checks or package adapters. `FluxClientPrepared(queue)` fires when preparation completes, including automatic continuation with unavailable assets; `queue.failures` records skipped content. This is a local presentation signal, not a permission or authentication boundary.

## Failure and menu behavior

The loading screen waits for the map/local player, role catalog and character-menu request. Helix still receives and owns character data. Flux defers building the menu until preparation finishes, preserving its native menu object and callbacks. Duplicate requests replace the pending menu; subsequent character switches do not repeat the initial preparation.

Missing content is recorded and skipped while the remaining queue continues. Collection errors, caps and asset timeouts also continue automatically with available content, retaining diagnostics in the queue and printing them to the client console. There is no asset Retry/Continue prompt. A server-data timeout still offers Retry connection/Exit server and never pretends character data arrived. Escape cannot open another Flux menu over active preparation. Resizing and the reduced-motion preference are respected.

No existing character, inventory, role or third-party plugin data is changed. A full restart/reconnect is required after installing the plugin or enabling it from a disabled startup.

The image revision is checked with `python flux-development/tests/test_loading_slides.py --render` (Lupa; optional Pillow for CPU previews). These are Lua 5.1 contract checks and software Paint replays with API fixtures, not native screenshots or remote-download verification. Plugin lifecycle checks also use an isolated native client on a private desktop, including admin toggles and disabled-startup character-menu fallbacks.
