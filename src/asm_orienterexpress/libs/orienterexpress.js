// Ruby → JS (settings)
function settingsJSON(config) {
  try {
    if (typeof config === "string") {
      config = JSON.parse(config);
    }

    if (window.app) {
      window._settingsLoading = true;

      window.app.settingsLanguage             = config.language;
      window.app.settingsContextMenu          = config.context_menu;
      window.app.rotationMode                 = config.rotation_mode || 'ground';
      window.app.settingsInsertionPointCustom = config.insertion_point_custom || {
        oevertex:  'origin',
        oecenter:  'center',
        oeflow:    'center',
        oesurface: 'base'
      };
      window.app.rollStep      = config.roll_step    != null ? config.roll_step    : 15;
      window.app.offsetStep    = config.offset_step  || '1cm';
      window.app.defaultRoll   = config.default_roll != null ? config.default_roll : 0;
      window.app.defaultOffset = config.default_offset || '0cm';
      window.app.smoothGroups  = config.smooth_groups ?? true;
      window.app.darkMode      = config.dark_mode  || false;
      window.app.debugMode     = config.debug_mode || false;

      window.app.$nextTick(() => {
        window._settingsLoading = false;
        window.app.appReady = true;
      });
    }

    updateDebugState(config.debug_mode);

    // Update the baseline AFTER loading the real config
    window.app.initialSettings = JSON.stringify(window.app.currentSettings());

  } catch (e) {
    console.error("settingsJSON failed:", e, config);
  }
}
