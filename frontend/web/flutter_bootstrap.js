{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();

    if ('serviceWorker' in navigator) {
      try {
        await navigator.serviceWorker.register(
          new URL('pwa_service_worker.js', document.baseURI),
        );
      } catch (error) {
        console.error('Business Manager service worker registration failed:', error);
      }
    }
  },
});
