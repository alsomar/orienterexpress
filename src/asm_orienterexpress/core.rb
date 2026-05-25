Sketchup.require 'asm_orienterexpress/config/init_config'
Sketchup.require 'asm_orienterexpress/lang/init_lang'
Sketchup.require 'asm_orienterexpress/ops/init_ops'
Sketchup.require 'asm_orienterexpress/dialogs/init_dialogs'

module ASM_Extensions
  module OrienterExpress

    ### MENU & TOOLBARS ### ------------------------------------------------------

    Lang.configure(CONFIG[:language] || "auto")

    unless file_loaded?(__FILE__)

      @commands = {}
      def self.commands
        @commands
      end

      @file_ext = Sketchup.platform == :platform_win ? 'svg' : 'pdf'
      def self.icon(basename)
        File.join(PATH_ICONS, "#{basename}.#{@file_ext}")
      end

      # Commands
      cmd = UI::Command.new(Lang.commands.oevertex.label.to_s) { self.oevertex_tool }
      cmd.small_icon = self.icon("oevertex_24")
      cmd.large_icon = self.icon("oevertex_32")
      cmd.status_bar_text = Lang.commands.oevertex.status
      cmd.tooltip = Lang.commands.oevertex.tooltip
      cmd_oevertex = cmd
      @commands[:oevertex] = cmd

      cmd = UI::Command.new(Lang.commands.oecenter.label.to_s) { self.oecenter_tool }
      cmd.small_icon = self.icon("oecenter_24")
      cmd.large_icon = self.icon("oecenter_32")
      cmd.status_bar_text = Lang.commands.oecenter.status
      cmd.tooltip = Lang.commands.oecenter.tooltip
      cmd_oecenter = cmd
      @commands[:oecenter] = cmd

      cmd = UI::Command.new(Lang.commands.oeaxisscale.label.to_s) { self.oeaxisscale_tool }
      cmd.small_icon = self.icon("oeaxisscale_24")
      cmd.large_icon = self.icon("oeaxisscale_32")
      cmd.status_bar_text = Lang.commands.oeaxisscale.status
      cmd.tooltip = Lang.commands.oeaxisscale.tooltip
      cmd_oeaxisscale = cmd
      @commands[:oeaxisscale] = cmd

      cmd = UI::Command.new(Lang.commands.oeuscale.label.to_s) { self.oeuscale_tool }
      cmd.small_icon = self.icon("oeuscale_24")
      cmd.large_icon = self.icon("oeuscale_32")
      cmd.status_bar_text = Lang.commands.oeuscale.status
      cmd.tooltip = Lang.commands.oeuscale.tooltip
      cmd_oeuscale = cmd
      @commands[:oeuscale] = cmd

      cmd = UI::Command.new(Lang.commands.oeflow.label.to_s) { self.oeflow_tool }
      cmd.small_icon = self.icon("oeflow_24")
      cmd.large_icon = self.icon("oeflow_32")
      cmd.status_bar_text = Lang.commands.oeflow.status
      cmd.tooltip = Lang.commands.oeflow.tooltip
      cmd_oeflow = cmd
      @commands[:oeflow] = cmd

      cmd = UI::Command.new(Lang.commands.oesurface.label.to_s) { self.oesurface_tool }
      cmd.small_icon = self.icon("oesurface_24")
      cmd.large_icon = self.icon("oesurface_32")
      cmd.status_bar_text = Lang.commands.oesurface.status
      cmd.tooltip = Lang.commands.oesurface.tooltip
      cmd_oesurface = cmd
      @commands[:oesurface] = cmd

      cmd = UI::Command.new(Lang.commands.oealigner_entity.label.to_s) { self.oealigner_entity_tool }
      cmd.small_icon = self.icon("oealigner_entity_24")
      cmd.large_icon = self.icon("oealigner_entity_32")
      cmd.status_bar_text = Lang.commands.oealigner_entity.status
      cmd.tooltip = Lang.commands.oealigner_entity.tooltip
      cmd_oealigner_entity = cmd
      @commands[:oealigner_entity] = cmd

      cmd = UI::Command.new(Lang.commands.oealigner_reference.label.to_s) { self.oealigner_reference_tool }
      cmd.small_icon = self.icon("oealigner_reference_24")
      cmd.large_icon = self.icon("oealigner_reference_32")
      cmd.status_bar_text = Lang.commands.oealigner_reference.status
      cmd.tooltip = Lang.commands.oealigner_reference.tooltip
      cmd_oealigner_reference = cmd
      @commands[:oealigner_reference] = cmd

      cmd = UI::Command.new(Lang.commands.oealigner_auto.label.to_s) { self.oealigner_auto_tool }
      cmd.small_icon = self.icon("oealigner_auto_24")
      cmd.large_icon = self.icon("oealigner_auto_32")
      cmd.status_bar_text = Lang.commands.oealigner_auto.status
      cmd.tooltip = Lang.commands.oealigner_auto.tooltip
      cmd_oealigner_auto = cmd
      @commands[:oealigner_auto] = cmd

      cmd = UI::Command.new(Lang.commands.oereset.label.to_s) { self.oereset_tool }
      cmd.small_icon = self.icon("oereset_24")
      cmd.large_icon = self.icon("oereset_32")
      cmd.status_bar_text = Lang.commands.oereset.status
      cmd.tooltip = Lang.commands.oereset.tooltip
      cmd_oereset = cmd
      @commands[:oereset] = cmd

      cmd = UI::Command.new(Lang.commands.tool_panel.label.to_s) { self.tool_panel_tool }
      cmd.status_bar_text = Lang.commands.tool_panel.status
      cmd.tooltip = Lang.commands.tool_panel.tooltip
      cmd.set_validation_proc { ASM_Extensions::OrienterExpress::Dialogs.tool_panel_visible? ? MF_CHECKED : MF_UNCHECKED }
      cmd_tool_panel = cmd
      @commands[:tool_panel] = cmd

      cmd = UI::Command.new(Lang.commands.settings.label.to_s) { self.settings_tool }
      cmd.small_icon = self.icon("oesettings_24")
      cmd.large_icon = self.icon("oesettings_32")
      cmd.status_bar_text = Lang.commands.settings.status
      cmd.tooltip = Lang.commands.settings.tooltip
      cmd_settings = cmd
      @commands[:settings] = cmd

      # Menu
      menu = UI.menu('Extensions').add_submenu(EXT_NAME)
      menu.add_item(cmd_oevertex)
      menu.add_item(cmd_oecenter)
      menu.add_item(cmd_oeflow)
      menu.add_item(cmd_oesurface)
      menu.add_separator
      menu.add_item(cmd_oeaxisscale)
      menu.add_item(cmd_oeuscale)
      menu.add_separator
      menu.add_item(cmd_oealigner_entity)
      menu.add_item(cmd_oealigner_reference)
      menu.add_item(cmd_oealigner_auto)
      menu.add_item(cmd_oereset)
      menu.add_separator
      menu.add_item(cmd_tool_panel)
      menu.add_item(cmd_settings)

      # Context menu
      UI.add_context_menu_handler do |context_menu|
        next unless CONFIG[:context_menu]
        menu = context_menu.add_submenu(EXT_NAME)
        menu.add_item(cmd_oevertex)
        menu.add_item(cmd_oecenter)
        menu.add_item(cmd_oeflow)
        menu.add_item(cmd_oesurface)
        menu.add_separator
        menu.add_item(cmd_oeaxisscale)
        menu.add_item(cmd_oeuscale)
        menu.add_separator
        menu.add_item(cmd_oealigner_entity)
        menu.add_item(cmd_oealigner_reference)
        menu.add_item(cmd_oealigner_auto)
        menu.add_item(cmd_oereset)
        menu.add_separator
        menu.add_item(cmd_settings)
      end

      # Placement toolbar
      toolbar = UI::Toolbar.new(EXT_NAME)
      toolbar.add_item(cmd_oevertex)
      toolbar.add_item(cmd_oecenter)
      toolbar.add_item(cmd_oeflow)
      toolbar.add_item(cmd_oesurface)
      toolbar.add_separator
      toolbar.add_item(cmd_oeaxisscale)
      toolbar.add_item(cmd_oeuscale)
      toolbar.add_separator
      toolbar.add_item(cmd_settings)

      if toolbar.get_last_state == TB_VISIBLE
        toolbar.restore
      else
        toolbar.show
      end

      # Transform toolbar (aligners + reset). Fixed name so its saved state
      # survives a language change.
      transform_tb = UI::Toolbar.new("#{EXT_NAME} Transform")
      transform_tb.add_item(cmd_oealigner_entity)
      transform_tb.add_item(cmd_oealigner_reference)
      transform_tb.add_item(cmd_oealigner_auto)
      transform_tb.add_separator
      transform_tb.add_item(cmd_oereset)
      transform_tb.add_separator
      transform_tb.add_item(cmd_settings)

      if transform_tb.get_last_state == TB_VISIBLE
        transform_tb.restore
      else
        transform_tb.show
      end

      ## TOOL METHODS ## ---------------------------------------------------------

      def self.oevertex_tool
        ASM_Extensions::OrienterExpress.oevertex
      end

      def self.oecenter_tool
        ASM_Extensions::OrienterExpress.oecenter
      end

      def self.oeaxisscale_tool
        ASM_Extensions::OrienterExpress.oeaxisscale
      end

      def self.oeuscale_tool
        ASM_Extensions::OrienterExpress.oeuscale
      end

      def self.oeflow_tool
        ASM_Extensions::OrienterExpress.oeflow
      end

      def self.oesurface_tool
        ASM_Extensions::OrienterExpress.oesurface
      end

      def self.oealigner_entity_tool
        ASM_Extensions::OrienterExpress.oealigner(:entity)
      end

      def self.oealigner_reference_tool
        ASM_Extensions::OrienterExpress.oealigner(:reference)
      end

      def self.oealigner_auto_tool
        ASM_Extensions::OrienterExpress.oealigner(:auto)
      end

      def self.oereset_tool
        ASM_Extensions::OrienterExpress.oereset
      end

      def self.settings_tool
        ASM_Extensions::OrienterExpress::Dialogs.settings_dialog
      end

      def self.tool_panel_tool
        ASM_Extensions::OrienterExpress::Dialogs.tool_panel_toggle
      end

      file_loaded(__FILE__)
    end

  end # module OrienterExpress
end # module ASM_Extensions
