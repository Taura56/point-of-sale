(() => {
  let deferredInstallPrompt = null;
  let installedFromPrompt = false;

  const isInstalled = () =>
    installedFromPrompt ||
    navigator.standalone === true ||
    window.matchMedia('(display-mode: standalone)').matches;

  window.addEventListener('beforeinstallprompt', (event) => {
    event.preventDefault();
    deferredInstallPrompt = event;
  });

  window.addEventListener('appinstalled', () => {
    installedFromPrompt = true;
    deferredInstallPrompt = null;
  });

  window.businessManagerPwaInstall = {
    isInstalled,
    async promptInstall() {
      if (isInstalled()) return 'installed';
      if (!deferredInstallPrompt) return 'manual';

      const installEvent = deferredInstallPrompt;
      deferredInstallPrompt = null;

      try {
        installEvent.prompt();
        const choice = await installEvent.userChoice;
        if (choice.outcome === 'accepted') {
          installedFromPrompt = true;
          return 'accepted';
        }
        return 'dismissed';
      } catch (error) {
        console.error('The app install prompt could not be opened:', error);
        return 'manual';
      }
    },
  };
})();
