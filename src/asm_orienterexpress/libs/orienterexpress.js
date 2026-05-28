// Ruby → JS: push tool state / schema / values to the tool panel.
function toolPanelUpdate(payload) {
  window._toolPanelLoading = true;
  try {
    if (typeof payload === "string") payload = JSON.parse(payload);
    if (!window.app) return;

    if (!payload || !payload.tool) {
      window.app.toolKey = null;
      window.app.toolTitle = "";
      window.app.toolSample = "";
      window.app.toolGeometry = { kind: null, count: 0 };
      window.app.toolPlaced = 0;
      window.app.schema = [];
      window.app.values = {};
    } else {
      window.app.toolKey      = payload.tool;
      window.app.toolTitle    = payload.title || "";
      window.app.toolSample   = payload.sample || "";
      window.app.toolGeometry = payload.geometry || { kind: null, count: 0 };
      window.app.toolPlaced   = payload.placed || 0;
      window.app.schema       = Array.isArray(payload.schema) ? payload.schema : [];
      window.app.values       = payload.values || {};
    }

    window.app.$nextTick(() => {
      window._toolPanelLoading = false;
      window.app.appReady = true;
    });
  } catch (e) {
    window._toolPanelLoading = false;
    console.error("toolPanelUpdate failed:", e);
  }
}

// JS → Ruby: user edited a field.
function toolPanelSet(key, value) {
  if (!window.sketchup || !window.sketchup.tool_panel_set) return;
  window.sketchup.tool_panel_set(JSON.stringify({ key: key, value: value }));
}

// JS → Ruby: user pressed a caret step button. Ruby owns the repeat cadence
// while held; JS only sends start/stop.
function toolPanelScrollStart(key, dir) {
  if (!window.sketchup || !window.sketchup.tool_panel_scroll_start) return;
  window.sketchup.tool_panel_scroll_start(JSON.stringify({ key: key, dir: dir }));
}
function toolPanelScrollStop() {
  if (!window.sketchup || !window.sketchup.tool_panel_scroll_stop) return;
  window.sketchup.tool_panel_scroll_stop("{}");
}

// JS → Ruby: user clicked the reset button for a field.
function toolPanelReset(key) {
  if (!window.sketchup || !window.sketchup.tool_panel_reset) return;
  window.sketchup.tool_panel_reset(JSON.stringify({ key: key }));
}

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
      window.app.defaultOffsetX = config.default_offset_x != null ? config.default_offset_x : 0;
      window.app.defaultOffsetY = config.default_offset_y != null ? config.default_offset_y : 0;
      window.app.defaultOffsetZ = config.default_offset_z != null ? config.default_offset_z : 0;
      window.app.rememberOffset = config.remember_offset != null ? config.remember_offset : true;
      window.app.rememberRoll   = config.remember_roll   != null ? config.remember_roll   : true;
      window.app.smoothGroups   = config.smooth_groups != null ? config.smooth_groups : true;
      // darkMode: localStorage (cross-extension live state) wins; the
      // per-extension config.dark_mode is the persistent fallback.
      const lsDark = readDarkModeFromStorage();
      window.app.darkMode      = lsDark !== null ? lsDark : !!config.dark_mode;
      window.app.debugMode     = config.debug_mode || false;

      wireDarkModeSync();

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
