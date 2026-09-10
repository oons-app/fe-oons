{{flutter_js}}
{{flutter_build_config}}

// Do not register Flutter's service worker — the generated SW unregisters itself
// and calls client.navigate(), which can loop and freeze lady.oons.app.
_flutter.loader.load({
  config: {
    // Use Google's CanvasKit CDN instead of pulling ~7MB wasm from our VPS.
    useLocalCanvasKit: false,
  },
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  },
});
