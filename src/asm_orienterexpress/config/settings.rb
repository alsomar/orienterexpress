require 'json'
require 'fileutils'

module ASM_Extensions
  module OrienterExpress

    DEFAULT_CONFIG = {
      # General Options
      language: "auto",
      context_menu: false,

      # Entity Options
      rotation_mode: "ground",
      insertion_point_custom: {
        oevertex: "origin",
        oecenter:     "center",
        oezscale:     "center",
        oeflow:       "center",
        oeface:       "base",
        oereset:      "base"
      },

      # Inner Options
      dark_mode: false,
      debug_mode: false,
      oevertex_offset: "0cm",
      oecenter_offset: "0cm",
      oezscale_offset: "10cm",
      oeface_offset:   "0cm",
      oeflow_offset:   "0cm"
    }.freeze

    MESSAGES = {
      invalid_sel:      "Please select at least one or more edges AND one group/component.",
      invalid_face_sel: "Please select at least one or more faces AND one group/component.",
      no_entities:      "Please select at least one or more groups/components."
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
        File.write(CONFIG_FILE, JSON.pretty_generate(config_hash))
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
    end

  end # module OrienterExpress
end # module ASM_Extensions
