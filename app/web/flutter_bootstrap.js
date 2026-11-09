{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: {canvasKitBaseUrl: 'canvaskit/'},
  onEntrypointLoaded: async engine => {
    const runner = await engine.initializeEngine({hostElement: document.getElementById('flutter-host'), canvasKitBaseUrl: 'canvaskit/'});
    document.getElementById('startup-status')?.remove();
    await runner.runApp();
  }
});
