# frozen_string_literal: true

require 'testup/testcase'

module ASM_Extensions
  module OrienterExpress
    class TC_config < TestUp::TestCase

      EXPECTED_KEYS = %i[
        language context_menu
        rotation_mode pivot_custom smooth_groups
        roll_step offset_step default_roll default_offset
        remember_offset remember_roll
        dark_mode debug_mode
        oevertex_offset oecenter_offset oeaxisscale_offset oeuscale_offset oesurface_offset oeflow_offset
        oevertex_roll oecenter_roll oeaxisscale_roll oeuscale_roll oesurface_roll oeflow_roll
      ].freeze

      # Keys sent by the frontend's currentSettings() — debug_mode is excluded intentionally
      FRONTEND_KEYS = (EXPECTED_KEYS - %i[debug_mode]).freeze

      # --- DEFAULT_CONFIG ---

      def test_default_config_is_frozen
        assert DEFAULT_CONFIG.frozen?
      end

      def test_default_config_has_all_expected_keys
        EXPECTED_KEYS.each do |key|
          assert DEFAULT_CONFIG.key?(key), "Missing key: #{key}"
        end
      end

      def test_default_config_boolean_values
        bool_keys = %i[context_menu dark_mode debug_mode remember_offset remember_roll smooth_groups]
        bool_keys.each do |key|
          val = DEFAULT_CONFIG[key]
          assert [true, false].include?(val), "#{key} should be boolean, got #{val.class}"
        end
      end

      def test_default_remember_flags_are_true
        assert_equal true, DEFAULT_CONFIG[:remember_offset]
        assert_equal true, DEFAULT_CONFIG[:remember_roll]
      end

      def test_default_per_tool_offset_and_roll_are_nil
        %i[oevertex oecenter oeaxisscale oeuscale oesurface oeflow].each do |tool|
          assert_nil DEFAULT_CONFIG["#{tool}_offset".to_sym], "#{tool}_offset should default to nil"
          assert_nil DEFAULT_CONFIG["#{tool}_roll".to_sym],   "#{tool}_roll should default to nil"
        end
      end

      def test_default_config_language_is_string
        assert_instance_of String, DEFAULT_CONFIG[:language]
      end

      def test_default_config_language_is_auto
        assert_equal "auto", DEFAULT_CONFIG[:language]
      end

      def test_default_config_pivot_custom_has_all_tool_keys
        custom = DEFAULT_CONFIG[:pivot_custom]
        assert_instance_of Hash, custom, "pivot_custom should be a Hash"
        expected_tools = %i[oevertex oecenter oeaxisscale oeflow oesurface oereset]
        expected_tools.each do |tool|
          assert custom.key?(tool), "pivot_custom missing tool key: #{tool}"
        end
      end

      def test_default_config_pivot_custom_values_are_valid
        valid = %w[center base origin]
        DEFAULT_CONFIG[:pivot_custom].each do |tool, value|
          assert_instance_of String, value,
            "pivot_custom[:#{tool}] should be a String, got #{value.class}"
          assert valid.include?(value),
            "pivot_custom[:#{tool}] = #{value.inspect} is not one of #{valid}"
        end
      end

      def test_frontend_keys_match_default_config
        FRONTEND_KEYS.each do |key|
          assert DEFAULT_CONFIG.key?(key), "DEFAULT_CONFIG missing frontend key: #{key}"
        end
        assert_equal FRONTEND_KEYS.sort, (DEFAULT_CONFIG.keys - %i[debug_mode]).sort,
          "Mismatch between frontend keys and DEFAULT_CONFIG keys (excluding debug_mode)"
      end

      # --- user_settings ---

      def test_user_settings_noop_when_unchanged
        current = OrienterExpress.load_config
        content_before = File.read(CONFIG_FILE)
        OrienterExpress.user_settings(current)
        content_after = File.read(CONFIG_FILE)
        assert_equal content_before, content_after, "user_settings should not write when nothing changed"
      end

      def test_user_settings_ignores_unknown_keys
        OrienterExpress.user_settings({ unknown_xyz: "injected" })
        result = OrienterExpress.load_config
        refute result.key?(:unknown_xyz), "user_settings should not save unknown keys"
      end

      # --- ensure_config ---

      def test_ensure_config_creates_file_if_missing
        FileUtils.rm_f(CONFIG_FILE)
        refute File.exist?(CONFIG_FILE), "Config file should be absent before test"
        OrienterExpress.ensure_config
        assert File.exist?(CONFIG_FILE), "ensure_config should create the config file"
      end

      # --- load_config ---

      def test_load_config_returns_hash
        result = load_config
        assert_instance_of Hash, result
      end

      def test_load_config_includes_all_default_keys
        result = load_config
        EXPECTED_KEYS.each do |key|
          assert result.key?(key), "load_config missing key: #{key}"
        end
      end

      def test_load_config_symbolizes_keys
        result = load_config
        result.each_key do |key|
          assert_instance_of Symbol, key, "Key #{key.inspect} should be a Symbol"
        end
      end

      # --- load_offset_str / default_offset_str ---

      def test_default_offset_str_matches_load_with_nil_key
        CONFIG[:default_offset] = "3cm"
        assert_equal OrienterExpress.load_offset_str(nil),
                     OrienterExpress.default_offset_str
      end

      def test_load_offset_str_falls_back_to_default_when_per_tool_nil
        CONFIG[:default_offset]   = "2cm"
        CONFIG[:oevertex_offset]  = nil
        assert_equal OrienterExpress.default_offset_str,
                     OrienterExpress.load_offset_str(:oevertex_offset)
      end

      def test_load_offset_str_prefers_stored_value_over_default
        CONFIG[:default_offset]  = "0cm"
        CONFIG[:oevertex_offset] = "5cm"
        refute_equal OrienterExpress.default_offset_str,
                     OrienterExpress.load_offset_str(:oevertex_offset)
      end

      # --- load_last_roll_deg / set_last_roll ---

      def test_load_last_roll_deg_falls_back_to_default_roll
        CONFIG[:oevertex_roll] = nil
        CONFIG[:default_roll]  = 12
        assert_equal 12.0, OrienterExpress.load_last_roll_deg(:oevertex)
      end

      def test_load_last_roll_deg_uses_stored_config_value
        CONFIG[:oevertex_roll] = 45
        assert_equal 45.0, OrienterExpress.load_last_roll_deg(:oevertex)
      end

      def test_load_last_roll_deg_cache_takes_precedence_over_config
        OrienterExpress.last_roll_store[:oevertex] = 90.0
        CONFIG[:oevertex_roll] = 45
        assert_equal 90.0, OrienterExpress.load_last_roll_deg(:oevertex)
      end

      def test_set_last_roll_persists_when_remember_roll_true
        CONFIG[:remember_roll] = true
        CONFIG[:oevertex_roll] = nil
        OrienterExpress.set_last_roll(:oevertex, 60.0)
        assert_equal 60.0, OrienterExpress.last_roll_store[:oevertex]
        assert_equal 60.0, CONFIG[:oevertex_roll]
      end

      def test_set_last_roll_skips_persist_when_remember_roll_false
        CONFIG[:remember_roll] = false
        CONFIG[:oevertex_roll] = nil
        OrienterExpress.set_last_roll(:oevertex, 60.0)
        assert_equal 60.0, OrienterExpress.last_roll_store[:oevertex]
        assert_nil CONFIG[:oevertex_roll]
      end

      private

      def setup
        @config_backup = File.exist?(CONFIG_FILE) ? File.read(CONFIG_FILE) : nil
        OrienterExpress.last_roll_store.clear
      end

      def teardown
        if @config_backup
          File.write(CONFIG_FILE, @config_backup)
          CONFIG.replace(JSON.parse(@config_backup, symbolize_names: true))
        else
          FileUtils.rm_f(CONFIG_FILE)
        end
        OrienterExpress.last_roll_store.clear
      end

      def load_config
        OrienterExpress.load_config
      end

    end
  end
end
