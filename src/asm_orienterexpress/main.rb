Sketchup.require 'asm_orienterexpress/data'

module ASM_Extensions
  module OrienterExpress

    ### MENU & TOOLBARS ### ------------------------------------------------------

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
      cmd = UI::Command.new('Origin Placement') {self.oeaxis_tool}
      cmd.small_icon = self.icon("oeaxis_24")
      cmd.large_icon = self.icon("oeaxis_24")
      cmd.status_bar_text = 'This one stands for axis.'
      cmd.tooltip = 'Origin Placement'
      cmd_oeaxis = cmd
      @commands[:oeaxis] = cmd

      cmd = UI::Command.new('Center Placement') {self.oecenter_tool}
      cmd.small_icon = self.icon("oecenter_24")
      cmd.large_icon = self.icon("oecenter_24")
      cmd.status_bar_text = 'This one stands for Benicarló.'
      cmd.tooltip = 'Center Placement'
      cmd_oecenter = cmd
      @commands[:oecenter] = cmd

      cmd = UI::Command.new('Z-axis Scaling') {self.oezscale_tool}
      cmd.small_icon = self.icon("oezscale_24")
      cmd.large_icon = self.icon("oezscale_24")
      cmd.status_bar_text = 'This one stands for Santa Pola.'
      cmd.tooltip = 'Z-axis Scaling'
      cmd_oezscale = cmd
      @commands[:oezscale] = cmd

      cmd = UI::Command.new('Uniform Scaling') {self.oeuscale_tool}
      cmd.small_icon = self.icon("oeuscale_24")
      cmd.large_icon = self.icon("oeuscale_24")
      cmd.status_bar_text = 'This one stands for Algeciras.'
      cmd.tooltip = 'Uniform Scaling'
      cmd_oeuscale = cmd
      @commands[:oeuscale] = cmd

      cmd = UI::Command.new('Vertex Placement') {self.oevertex_tool}
      cmd.small_icon = self.icon("oevertex_24")
      cmd.large_icon = self.icon("oevertex_24")
      cmd.status_bar_text = 'This one stands for Algeciras.'
      cmd.tooltip = 'Vertex Placement'
      cmd_oevertex = cmd
      @commands[:oevertex] = cmd

      cmd = UI::Command.new('Reset Rotations') {self.oereset_tool}
      cmd.small_icon = self.icon("oereset_24")
      cmd.large_icon = self.icon("oereset_24")
      cmd.status_bar_text = 'This one stands for Algeciras.'
      cmd.tooltip = 'Reset Rotations'
      cmd_oereset = cmd
      @commands[:oereset] = cmd

      cmd = UI::Command.new('OrienterExpress Settings') {self.settings_tool}
      cmd.small_icon = self.icon("settings_24")
      cmd.large_icon = self.icon("settings_24")
      cmd.status_bar_text = 'Settings'
      cmd.tooltip = 'OrienterExpress Settings'
      cmd_settings = cmd
      @commands[:settings] = cmd

      # Menu
      menu = UI.menu('Extensions').add_submenu(PLUGIN_NAME)
      menu.add_item(cmd_oeaxis)
      menu.add_item(cmd_oecenter)
      menu.add_item(cmd_oezscale)
      menu.add_item(cmd_oeuscale)
      menu.add_item(cmd_oevertex)
      menu.add_separator
      menu.add_item(cmd_oereset)
      menu.add_separator
      menu.add_item(cmd_settings)

      # Context menu
      UI.add_context_menu_handler do |context_menu|
        next unless CONTEXT_ON[:context_menu]
        menu = context_menu.add_submenu(PLUGIN_NAME)
        menu.add_item(cmd_oeaxis)
        menu.add_item(cmd_oecenter)
        menu.add_item(cmd_oezscale)
        menu.add_item(cmd_oeuscale)
        menu.add_item(cmd_oevertex)
        menu.add_separator
        menu.add_item(cmd_oereset)
        menu.add_separator
        menu.add_item(cmd_settings)
      end

      # Toolbar
      toolbar = UI::Toolbar.new (PLUGIN_NAME)
      toolbar.add_item(cmd_oeaxis)
      toolbar.add_item(cmd_oecenter)
      toolbar.add_item(cmd_oezscale)
      toolbar.add_item(cmd_oeuscale)
      toolbar.add_item(cmd_oevertex)
      toolbar.add_separator
      toolbar.add_item(cmd_oereset)
      toolbar.add_separator
      toolbar.add_item(cmd_settings)

      if toolbar.get_last_state == TB_VISIBLE
        toolbar.restore
      else
        toolbar.show
      end

      ## MAIN SCRIPTS ## ---------------------------------------------------------

      def self.oeaxis_tool
        ASM_Extensions::OrienterExpress.oeaxis
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

      def self.oevertex_tool
        ASM_Extensions::OrienterExpress.oevertex
      end

      def self.oereset_tool
        ASM_Extensions::OrienterExpress.oereset
      end

      def self.settings_tool
        ASM_Extensions::OrienterExpress.settings_dialog
      end

      file_loaded(__FILE__)
    end

  end # module OrienterExpress
end # module ASM_Extensions
