require 'json'

module ASM_Extensions
  module OrienterExpress
    module Dialogs

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
        config  = ASM_Extensions::OrienterExpress.load_config
        payload = { locale: Lang.locale.to_s, data: Lang.dump }.to_json
        dialog.execute_script("settingsJSON(#{config.to_json.inspect})")
        dialog.execute_script("i18nJSON(#{payload.inspect})")
      end

      # Called by user_settings whenever config changes so an open dialog stays
      # in sync with changes made during tool execution (e.g. insertion point).
      def self.refresh_settings_dialog
        return unless @settings && @settings.visible?
        push_initial_data(@settings)
      end

      private_class_method :push_initial_data

    end # module Dialogs
  end # module OrienterExpress
end # module ASM_Extensions
