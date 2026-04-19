require 'json'

module ASM_Extensions
  module OrienterExpress
    module Dialogs

      @tool_panel       = nil   unless instance_variable_defined?(:@tool_panel)
      @tool_panel_ready = false unless instance_variable_defined?(:@tool_panel_ready)

      def self.tool_panel_visible?
        @tool_panel && @tool_panel.visible?
      end

      def self.tool_panel_ready?
        @tool_panel_ready && tool_panel_visible?
      end

      def self.tool_panel_toggle
        if tool_panel_visible?
          close_tool_panel
        else
          open_tool_panel
        end
      end

      def self.open_tool_panel
        if @tool_panel
          @tool_panel.show unless @tool_panel.visible?
          @tool_panel.bring_to_front
          if @tool_panel_ready
            push_tool_panel_i18n
            push_tool_panel_modes
            push_tool_state(active_placement_tool)
          end
          return
        end

        html_file = File.join(PATH_HTML, 'tool_panel.html')

        Lang.configure(CONFIG[:language] || "auto") if Lang.dictionary.empty?
        html_title = "#{EXT_NAME} #{INFO_VERSION} · #{Lang.t(:html, :tool_panel, :title).to_s.upcase}"

        options = {
          dialog_title:     html_title,
          preferences_key:  "asm_extensions.htmldialog.orienterexpress_tool_panel",
          style:            UI::HtmlDialog::STYLE_DIALOG,
          resizable:        false,
          width:            480,
          height:           620,
          use_content_size: true
        }

        dialog = UI::HtmlDialog.new(options)
        dialog.set_file(html_file)
        @tool_panel = dialog

        dialog.add_action_callback("ready") do |_ctx|
          @tool_panel_ready = true
          push_tool_panel_i18n
          push_tool_panel_modes
          push_tool_state(active_placement_tool)
        end

        dialog.add_action_callback("tool_panel_set") do |_ctx, json|
          begin
            payload = JSON.parse(json, symbolize_names: true)
            key     = payload[:key]
            value   = payload[:value]
            tool    = active_placement_tool
            if tool && key && tool.respond_to?(:apply_panel_change)
              tool.apply_panel_change(key.to_sym, value)
            end
          rescue => e
            Debug.log(self, :tool_panel_set, e.message)
          end
        end

        dialog.add_action_callback("tool_panel_scroll_start") do |_ctx, json|
          begin
            payload = JSON.parse(json, symbolize_names: true)
            key     = payload[:key]
            dir     = payload[:dir]
            tool    = active_placement_tool
            if tool && key && tool.respond_to?(:apply_panel_scroll_start)
              tool.apply_panel_scroll_start(key.to_sym, dir)
            end
          rescue => e
            Debug.log(self, :tool_panel_scroll_start, e.message)
          end
        end

        dialog.add_action_callback("tool_panel_scroll_stop") do |_ctx, _json|
          begin
            tool = active_placement_tool
            tool.apply_panel_scroll_stop if tool && tool.respond_to?(:apply_panel_scroll_stop)
          rescue => e
            Debug.log(self, :tool_panel_scroll_stop, e.message)
          end
        end

        dialog.add_action_callback("activate_tool") do |_ctx, json|
          begin
            payload = JSON.parse(json, symbolize_names: true)
            key     = payload[:key].to_s
            allowed = %w[oevertex oecenter oeaxisscale oeuscale oeflow oesurface]
            if allowed.include?(key) && OrienterExpress.respond_to?(key)
              OrienterExpress.send(key)
            end
          rescue => e
            Debug.log(self, :activate_tool, e.message)
          end
        end

        dialog.add_action_callback("tool_panel_reset") do |_ctx, json|
          begin
            payload = JSON.parse(json, symbolize_names: true)
            key     = payload[:key]
            tool    = active_placement_tool
            if tool && key && tool.respond_to?(:apply_panel_reset)
              tool.apply_panel_reset(key.to_sym)
            end
          rescue => e
            Debug.log(self, :tool_panel_reset, e.message)
          end
        end

        dialog.set_on_closed { @tool_panel = nil; @tool_panel_ready = false }
        dialog.show
      end

      def self.close_tool_panel
        return unless @tool_panel
        dialog = @tool_panel
        @tool_panel = nil
        @tool_panel_ready = false
        dialog.close
      end

      def self.push_tool_panel_i18n
        return unless tool_panel_ready?
        Lang.configure(CONFIG[:language] || "auto") if Lang.dictionary.empty?
        payload = { locale: Lang.locale.to_s, data: Lang.dump }.to_json
        @tool_panel.execute_script("i18nJSON(#{payload.inspect})")
      rescue => e
        Debug.log(self, :push_tool_panel_i18n, "#{e.class}: #{e.message}")
      end

      def self.push_tool_panel_modes
        return unless tool_panel_ready?
        @tool_panel.execute_script("updateDarkMode(#{!!CONFIG[:dark_mode]})")
        @tool_panel.execute_script("updateDebugState(#{!!CONFIG[:debug_mode]})")
      rescue => e
        Debug.log(self, :push_tool_panel_modes, "#{e.class}: #{e.message}")
      end

      def self.refresh_tool_panel
        return unless tool_panel_ready?
        push_tool_panel_i18n
        push_tool_panel_modes
        push_tool_state(active_placement_tool)
      end

      def self.push_tool_state(tool)
        method_id = __method__
        unless tool_panel_ready?
          Debug.log(self, method_id, "skipped: panel not ready (tool=#{tool.class})")
          return
        end
        has_ps  = tool && tool.respond_to?(:panel_state)
        payload = has_ps ? tool.panel_state : { 'tool' => nil }
        Debug.log(self, method_id, "tool=#{tool.class} has_panel_state=#{has_ps} payload.tool=#{payload['tool'].inspect}")
        script = "toolPanelUpdate(#{payload.to_json.inspect})"
        @tool_panel.execute_script(script)
      rescue => e
        Debug.log(self, method_id, "failed: #{e.class}: #{e.message}")
        Debug.log(self, method_id, e.backtrace.first(5).join(" | ")) if e.backtrace
      end

      def self.active_placement_tool
        return nil unless defined?(OEPlacementTool)
        OEPlacementTool.active_instance
      end

      private_class_method :active_placement_tool

    end # module Dialogs
  end # module OrienterExpress
end # module ASM_Extensions
