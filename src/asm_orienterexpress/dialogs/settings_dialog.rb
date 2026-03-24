require 'json'

module ASM_Extensions
  module OrienterExpress
    module Dialogs

      @settings = nil

      def self.settings_dialog
        if @settings && @settings.visible?
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

        @settings = UI::HtmlDialog.new(options)
        @settings.set_file(html_file)

        # Sends current config and i18n payload to the dialog
        @settings.add_action_callback("ready") do |_context|
          config  = ASM_Extensions::OrienterExpress.load_config
          payload = { locale: Lang.locale.to_s, data: Lang.dump }.to_json

          @settings.execute_script("settingsJSON(#{config.to_json.inspect})")
          @settings.execute_script("i18nJSON(#{payload.inspect})")
        end

        # Receives updated settings from JS and saves them
        @settings.add_action_callback("user_settings") do |_context, settings_json|
          settings = JSON.parse(settings_json, symbolize_names: true)
          ASM_Extensions::OrienterExpress.user_settings(settings)

          if settings.key?(:language)
            Lang.configure(settings[:language])
            payload = { locale: Lang.locale.to_s, data: Lang.dump }.to_json
            @settings.execute_script("i18nJSON(#{payload.inspect})")
          end
        end

        @settings.center
        @settings.show
      end

    end # module Dialogs
  end # module OrienterExpress
end # module ASM_Extensions
