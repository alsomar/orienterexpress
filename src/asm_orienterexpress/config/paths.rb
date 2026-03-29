require "sketchup"
require "fileutils"

module ASM_Extensions
  module OrienterExpress

    # Root folder for user configuration
    CONFIG_ROOT =
      if Sketchup.platform == :platform_win
        ENV["LOCALAPPDATA"] || Dir.home
      else
        File.expand_path("~/Library/Application Support")
      end

    CONFIG_FOLDER = File.join(CONFIG_ROOT, "ASM_Extensions", EXT_ID).freeze

    # Ensure config folder exists (safe if already exists)
    FileUtils.mkdir_p(CONFIG_FOLDER)

    # Extension paths
    PATH_VENDOR  = File.join(EXT_DIR, "vendor").freeze
    PATH_ICONS   = File.join(EXT_DIR, "graphics", "icons").freeze
    PATH_CURSORS = File.join(EXT_DIR, "graphics", "cursors").freeze
    PATH_HTML    = File.join(EXT_DIR, "html").freeze

    # User config file
    CONFIG_FILE = File.join(CONFIG_FOLDER, ".#{EXT_ID}.json").freeze

  end # module OrienterExpress
end # module ASM_Extensions
