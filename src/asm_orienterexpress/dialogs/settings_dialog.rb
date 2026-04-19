require 'json'

module ASM_Extensions
  module OrienterExpress
    module Dialogs

      # SketchUp LengthUnit id → display info. `factor` converts SketchUp's
      # internal inches to the display unit; `step` is the numeric input step.
      UNIT_FACTORS = {
        0 => { name: "in", factor: 1.0,        step: 0.01 },
        1 => { name: "ft", factor: 1.0 / 12.0, step: 0.01 },
        2 => { name: "mm", factor: 25.4,       step: 0.1  },
        3 => { name: "cm", factor: 2.54,       step: 0.01 },
        4 => { name: "m",  factor: 0.0254,     step: 0.001 }
      }.freeze

      def self.unit_info
        model = Sketchup.active_model
        unit_id = model ? model.options["UnitsOptions"]["LengthUnit"] : 2
        UNIT_FACTORS[unit_id] || UNIT_FACTORS[2]
      end

      # Parse a stored length string (e.g. "1cm") into a numeric display value
      # in the current model unit. Returns 0 if parsing fails.
      def self.length_to_display(str, unit)
        inches = str.to_s.to_l.to_f
        (inches * unit[:factor]).round(4)
      rescue ArgumentError
        0
      end

      # Preserve the dialog reference across extension reloads so we can
      # re-push data to an already-open dialog without creating a duplicate.
      @settings = nil unless instance_variable_defined?(:@settings)

      def self.settings_dialog
        if @settings && @settings.visible?
          push_initial_data(@settings)
          @settings.bring_to_front
          return
        end

        html_file  = File.join(PATH_HTML, 'settings.html')
        html_title = "#{EXT_NAME} #{INFO_VERSION}"

        options = {
          dialog_title:    html_title,
          preferences_key: "asm_extensions.htmldialog.orienterexpress_settings",
          style:           UI::HtmlDialog::STYLE_DIALOG,
          resizable:       false,
          width:           420,
          height:          620,
          use_content_size: true
        }

        dialog = UI::HtmlDialog.new(options)
        dialog.set_file(html_file)
        @settings = dialog

        # Uses the local `dialog` variable so callbacks remain valid even if
        # a reload resets @settings to nil on the module level.
        dialog.add_action_callback("ready") do |_context|
          push_initial_data(dialog)
        end

        dialog.add_action_callback("user_settings") do |_context, settings_json|
          settings = JSON.parse(settings_json, symbolize_names: true)

          # Offset fields come in as numeric (display unit). Reformat to the
          # suffixed string form the rest of the code expects (e.g. "1.5cm").
          unit = unit_info
          [:offset_step, :default_offset].each do |key|
            next unless settings.key?(key) && settings[key].is_a?(Numeric)
            settings[key] = "#{settings[key]}#{unit[:name]}"
          end

          ASM_Extensions::OrienterExpress.user_settings(settings)

          if settings.key?(:language)
            Lang.configure(settings[:language])
            payload = { locale: Lang.locale.to_s, data: Lang.dump }.to_json
            dialog.execute_script("i18nJSON(#{payload.inspect})")
          end
        end

        dialog.center
        dialog.show
      end

      # Ensures i18n data is always loaded before pushing to the dialog.
      # Called both from the `ready` callback and when bringing the dialog
      # to front, so a reload never leaves the dialog with stale/empty data.
      def self.push_initial_data(dialog)
        Lang.configure(CONFIG[:language] || "auto") if Lang.dictionary.empty?
        config = ASM_Extensions::OrienterExpress.load_config
        unit   = unit_info

        config = config.dup
        config[:offset_step]    = length_to_display(config[:offset_step],    unit)
        config[:default_offset] = length_to_display(config[:default_offset], unit)

        settings_payload = { config: config, unit: unit }
        i18n_payload     = { locale: Lang.locale.to_s, data: Lang.dump }.to_json

        dialog.execute_script("settingsJSON(#{settings_payload.to_json.inspect})")
        dialog.execute_script("i18nJSON(#{i18n_payload.inspect})")
      end

      # Called by user_settings whenever config changes so an open dialog stays
      # in sync with changes made during tool execution (e.g. pivot).
      def self.refresh_settings_dialog
        return unless @settings && @settings.visible?
        push_initial_data(@settings)
      end

      private_class_method :push_initial_data

    end # module Dialogs
  end # module OrienterExpress
end # module ASM_Extensions
