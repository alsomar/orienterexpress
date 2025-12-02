const DEBUG = true;

function settingsJSON(config) {
  try {
    if (typeof config === "string") {
      if (DEBUG) console.log("Parsing JSON from Ruby:", config);
      config = JSON.parse(config);
    }
    if (DEBUG) console.log("Applying config to Vue:", config);

    if (window.app) {
      window.app.settingsLanguage    = config.language;
      window.app.settingsContextMenu = config.context_menu;
    }
    
    // Update the baseline AFTER loading the real config
    if (window.app) {
      window.app.initialSettings = JSON.stringify(window.app.currentSettings());
    }

  } catch (e) {
    console.error("settingsJSON failed:", e, config);
  }
}

function infoJSON(meta) {
  try {
    if (typeof meta === "string") {
      if (DEBUG) console.log("Parsing plugin metadata from Ruby:", meta);
      meta = JSON.parse(meta);
    }
    if (DEBUG) console.log("Applying plugin metadata to Vue:", meta);

    if (!window.app) return;

    var name        = meta.name        || "";
    var version     = meta.version     || "";
    var description = meta.description || "";
    var copyright   = meta.copyright   || "";
    var release     = meta.release     || "";
    var update      = meta.update      || "";
    var url_ew      = meta.url_ew      || "";
    var url_su      = meta.url_su      || "";
    var url_gh      = meta.url_gh      || "";

    window.app.extName        = name;
    window.app.extDescription = description;
    window.app.extVersion     = version;
    window.app.extCopyright   = copyright;
    window.app.extRelease     = release;
    window.app.extUpdate      = update;
    window.app.extEW          = url_ew;
    window.app.extSU          = url_su;
    window.app.extGH          = url_gh;

  } catch (e) {
    console.error("infoJSON failed:", e, meta);
  }
}

function thanksContent() {
    var selectedValue = document.getElementById("formSelect").value;
    var contentPrefix = "content_";
    var contentElements = document.querySelectorAll('[id^="' + contentPrefix + '"]');

    contentElements.forEach(function(contentElement) {
        contentElement.style.display = "none";
    });

    var selectedContent = document.getElementById(contentPrefix + selectedValue);
    if (selectedContent) {
        selectedContent.style.display = "block";
    }
}
