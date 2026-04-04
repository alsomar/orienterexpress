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
      cmd = UI::Command.new(Lang.commands.oeedgevertex.label.to_s) { self.oeedgevertex_tool }
      cmd.small_icon = self.icon("oevertex_24")
      cmd.large_icon = self.icon("oevertex_32")
      cmd.status_bar_text = Lang.commands.oeedgevertex.status
      cmd.tooltip = Lang.commands.oeedgevertex.tooltip
      cmd_oeedgevertex = cmd
      @commands[:oeedgevertex] = cmd

      cmd = UI::Command.new(Lang.commands.oecenter.label.to_s) { self.oecenter_tool }
      cmd.small_icon = self.icon("oecenter_24")
      cmd.large_icon = self.icon("oecenter_32")
      cmd.status_bar_text = Lang.commands.oecenter.status
      cmd.tooltip = Lang.commands.oecenter.tooltip
      cmd_oecenter = cmd
      @commands[:oecenter] = cmd

      cmd = UI::Command.new(Lang.commands.oezscale.label.to_s) { self.oezscale_tool }
      cmd.small_icon = self.icon("oezscale_24")
      cmd.large_icon = self.icon("oezscale_32")
      cmd.status_bar_text = Lang.commands.oezscale.status
      cmd.tooltip = Lang.commands.oezscale.tooltip
      cmd_oezscale = cmd
      @commands[:oezscale] = cmd

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

      cmd = UI::Command.new(Lang.commands.oeface.label.to_s) { self.oeface_tool }
      cmd.small_icon = self.icon("oeface_24")
      cmd.large_icon = self.icon("oeface_32")
      cmd.status_bar_text = Lang.commands.oeface.status
      cmd.tooltip = Lang.commands.oeface.tooltip
      cmd_oeface = cmd
      @commands[:oeface] = cmd

      cmd = UI::Command.new(Lang.commands.oealignoptimal.label.to_s) { self.oealignoptimal_tool }
      cmd.small_icon = self.icon("oeoptimal_24")
      cmd.large_icon = self.icon("oeoptimal_32")
      cmd.status_bar_text = Lang.commands.oealignoptimal.status
      cmd.tooltip = Lang.commands.oealignoptimal.tooltip
      cmd_oealignoptimal = cmd
      @commands[:oealignoptimal] = cmd

      cmd = UI::Command.new(Lang.commands.oereset.label.to_s) { self.oereset_tool }
      cmd.small_icon = self.icon("oereset_24")
      cmd.large_icon = self.icon("oereset_32")
      cmd.status_bar_text = Lang.commands.oereset.status
      cmd.tooltip = Lang.commands.oereset.tooltip
      cmd_oereset = cmd
      @commands[:oereset] = cmd

      cmd = UI::Command.new(Lang.commands.settings.label.to_s) { self.settings_tool }
      cmd.small_icon = self.icon("oesettings_24")
      cmd.large_icon = self.icon("oesettings_32")
      cmd.status_bar_text = Lang.commands.settings.status
      cmd.tooltip = Lang.commands.settings.tooltip
      cmd_settings = cmd
      @commands[:settings] = cmd

      # Menu
      menu = UI.menu('Extensions').add_submenu(EXT_NAME)
      menu.add_item(cmd_oeedgevertex)
      menu.add_item(cmd_oecenter)
      menu.add_item(cmd_oeflow)
      menu.add_item(cmd_oeface)
      menu.add_separator
      menu.add_item(cmd_oezscale)
      menu.add_item(cmd_oeuscale)
      menu.add_separator
      menu.add_item(cmd_oealignoptimal)
      menu.add_item(cmd_oereset)
      menu.add_separator
      menu.add_item(cmd_settings)

      # Context menu
      UI.add_context_menu_handler do |context_menu|
        next unless CONFIG[:context_menu]
        menu = context_menu.add_submenu(EXT_NAME)
        menu.add_item(cmd_oeedgevertex)
        menu.add_item(cmd_oecenter)
        menu.add_item(cmd_oeflow)
        menu.add_item(cmd_oeface)
        menu.add_separator
        menu.add_item(cmd_oezscale)
        menu.add_item(cmd_oeuscale)
        menu.add_separator
        menu.add_item(cmd_oealignoptimal)
        menu.add_item(cmd_oereset)
        menu.add_separator
        menu.add_item(cmd_settings)
      end

      # Toolbar
      toolbar = UI::Toolbar.new(EXT_NAME)
      toolbar.add_item(cmd_oeedgevertex)
      toolbar.add_item(cmd_oecenter)
      toolbar.add_item(cmd_oeflow)
      toolbar.add_item(cmd_oeface)
      toolbar.add_separator
      toolbar.add_item(cmd_oezscale)
      toolbar.add_item(cmd_oeuscale)
      toolbar.add_separator
      toolbar.add_item(cmd_oealignoptimal)
      toolbar.add_item(cmd_oereset)
      toolbar.add_separator
      toolbar.add_item(cmd_settings)

      if toolbar.get_last_state == TB_VISIBLE
        toolbar.restore
      else
        toolbar.show
      end

      ## TOOL METHODS ## ---------------------------------------------------------

      def self.oeedgevertex_tool
        ASM_Extensions::OrienterExpress.oeedgevertex
      end

      def self.oecenter_tool
        ASM_Extensions::OrienterExpress.oecenter
      end

      def self.oezscale_tool
        ASM_Extensions::OrienterExpress.oezscale
      end

      def self.oeuscale_tool
        ASM_Extensions::OrienterExpress.oeuscale
      end

      def self.oeflow_tool
        ASM_Extensions::OrienterExpress.oeflow
      end

      def self.oeface_tool
        ASM_Extensions::OrienterExpress.oeface
      end

      def self.oealignoptimal_tool
        ASM_Extensions::OrienterExpress.oealignoptimal
      end

      def self.oereset_tool
        ASM_Extensions::OrienterExpress.oereset
      end

      def self.settings_tool
        ASM_Extensions::OrienterExpress::Dialogs.settings_dialog
      end

      file_loaded(__FILE__)
    end

  end # module OrienterExpress
end # module ASM_Extensions
