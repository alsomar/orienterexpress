// Ruby → JS (settings)
function settingsJSON(payload) {
  try {
    if (typeof payload === "string") {
      payload = JSON.parse(payload);
    }

    // Back-compat: Ruby now sends { config, unit }; accept bare config too.
    var config = payload && payload.config ? payload.config : payload;
    var unit   = (payload && payload.unit)  || { name: 'cm', step: 0.01 };

    if (window.app) {
      window._settingsLoading = true;

      window.app.settingsLanguage             = config.language;
      window.app.settingsContextMenu          = config.context_menu;
      window.app.rotationMode                 = config.rotation_mode || 'ground';
      window.app.settingsPivotCustom          = config.pivot_custom || {
        oevertex:  'origin',
        oecenter:  'center',
        oeflow:    'center',
        oesurface: 'base'
      };
      window.app.unitName      = unit.name;
      window.app.unitStep      = unit.step;
      window.app.rollStep       = config.roll_step     != null ? config.roll_step     : 15;
      window.app.offsetStep     = config.offset_step   != null ? config.offset_step   : 1;
      window.app.defaultRoll    = config.default_roll  != null ? config.default_roll  : 0;
      window.app.defaultOffset  = config.default_offset != null ? config.default_offset : 0;
      window.app.rememberOffset = config.remember_offset != null ? config.remember_offset : true;
      window.app.rememberRoll   = config.remember_roll   != null ? config.remember_roll   : true;
      window.app.smoothGroups   = config.smooth_groups ?? true;
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
