require 'json'
require 'fileutils'

module ASM_Extensions
  module OrienterExpress

    DEFAULT_CONFIG = {
      # General Options
      language:       "auto",
      context_menu:   false,

      # Entity Options
      rotation_mode:  "ground",
      pivot_custom: {
        oevertex:     "center",
        oecenter:     "center",
        oeaxisscale:  "center",
        oeuscale:     "center",
        oeflow:       "center",
        oesurface:    "base",
        oereset:      "center"
      },

      # Step sizes and defaults
      roll_step:      5,
      default_roll:   0,
      offset_step:    "1cm",
      default_offset: "0cm",

      # Remember last used values per tool
      remember_offset: true,
      remember_roll:   true,

      # Inner Options
      dark_mode:          false,
      debug_mode:         false,
      smooth_groups:      true,
      oevertex_offset:    nil,
      oecenter_offset:    nil,
      oeaxisscale_offset: nil,
      oeuscale_offset:    nil,
      oesurface_offset:   nil,
      oeflow_offset:      nil,
      oevertex_roll:      nil,
      oecenter_roll:      nil,
      oeaxisscale_roll:   nil,
      oeuscale_roll:      nil,
      oesurface_roll:     nil,
      oeflow_roll:        nil
    }.freeze

    def self.ensure_config
      FileUtils.mkdir_p(CONFIG_FOLDER)
      return if File.exist?(CONFIG_FILE)

      File.write(CONFIG_FILE, JSON.pretty_generate(DEFAULT_CONFIG))
    end

    def self.load_config
      method_id = __method__
      ensure_config

      begin
        loaded = JSON.parse(File.read(CONFIG_FILE), symbolize_names: true)
        DEFAULT_CONFIG.merge(loaded)
      rescue => e
        Debug.log(self, method_id, "Config load failed: #{e.message}")
        DEFAULT_CONFIG.dup
      end
    end

    CONFIG = load_config

    def self.save_config(config_hash)
      method_id = __method__
      ensure_config

      begin
        # Drop keys no longer in DEFAULT_CONFIG so stale entries from older
        # versions (renamed or removed tools) get pruned on the next save
        # instead of lingering in the JSON forever.
        pruned = config_hash.select { |k, _| DEFAULT_CONFIG.key?(k) }
        File.write(CONFIG_FILE, JSON.pretty_generate(pruned))
      rescue => e
        Debug.log(self, method_id, "Failed to save config: #{e.message}")
      end
    end

    def self.user_settings(settings)
      method_id = __method__
      current = load_config

      changed = {}

      settings.each do |key, new_value|
        next unless current.key?(key)
        next if current[key] == new_value
        changed[key] = new_value
      end

      return if changed.empty?

      merged = current.merge(changed)
      save_config(merged)

      CONFIG.merge!(changed)

      # Special log for debug_mode, always visible
      if changed.key?(:debug_mode)
        state = changed[:debug_mode] ? "ON" : "OFF"
        puts "[#{Time.now.strftime('%H:%M:%S')}][#{EXT_NAME}.#{method_id}] DEBUG mode is #{state}"
      end

      changed.each do |key, new_value|
        next if key == :debug_mode
        Debug.log(self, method_id, "#{key}: #{new_value.inspect}")
      end

      Dialogs.refresh_settings_dialog
      inst = OEPlacementTool.active_instance
      inst.on_config_changed(changed) if inst
    end

  end # module OrienterExpress
end # module ASM_Extensions
