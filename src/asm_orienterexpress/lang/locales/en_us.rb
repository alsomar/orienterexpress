# frozen_string_literal: true

module ASM_Extensions
  module OrienterExpress
    module Lang
      def self.locale_en_us
        {
          commands: {
            oeaxis: {
              label:   "Origin Placement",
              tooltip: "Origin Placement",
              status:  "Place copies at edge start points."
            },
            oecenter: {
              label:   "Center Placement",
              tooltip: "Center Placement",
              status:  "Place copies centered on edges."
            },
            oezscale: {
              label:   "Z-axis Scaling",
              tooltip: "Z-axis Scaling",
              status:  "Scale and place copies along edges (Z-axis)."
            },
            oeuscale: {
              label:   "Uniform Scaling",
              tooltip: "Uniform Scaling",
              status:  "Scale uniformly and place copies along edges."
            },
            oevertex: {
              label:   "Vertex Placement",
              tooltip: "Vertex Placement",
              status:  "Place copies at edge vertices."
            },
            oereset: {
              label:   "Reset Rotations",
              tooltip: "Reset Rotations",
              status:  "Reset rotation of selected entities to global axes."
            },
            settings: {
              label:   "#{EXT_NAME} Settings",
              tooltip: "#{EXT_NAME} Settings",
              status:  "Open #{EXT_NAME} settings."
            }
          },

          html: {
            settings: {
              title:              "Settings",
              tooltip:            "Settings",
              dark_mode_tooltip:  "Switch to light mode",
              light_mode_tooltip: "Switch to dark mode",
              general_options:    "General Options",
              language_selection: "Language selection",
              language_hint:      "You may need to restart SketchUp to update the language settings.",
              system_language:    "(system language)",
              context_menu:       "Display context menu",
              reset_button:       "Show reset button",
              reset_settings:     "Reset settings",
              reset_confirm_body: "This will reset all settings to their default values. Are you sure?",
              reset_confirm_yes:  "Yes, reset",
              reset_confirm_no:   "Cancel"
            },
            about: {
              title:       "Info",
              tooltip:     "Info",
              version:     "Version ",
              designed_by: "Designed and developed by #{LINK_ALEJANDRO}.",
              uses:        "This extension uses #{LINK_MODUS}.",
              warning:     "<b>#{EXT_NAME} is free!</b> Trust only #{LINK_EXT_WAREHOUSE} and #{LINK_SKETCHUCATION} to download it."
            },
            thanks: {
              title:   "Thanks",
              tooltip: "Thanks",
              txt1:    "Thanks to the developer communities at #{LINK_SKP_FORUMS} and #{LINK_SUC_FORUMS} for sharing their knowledge and lending a hand to new developers.",
              txt2:    "Community support is what makes independent projects like #{EXT_NAME} possible. If you can, please consider making a contribution through #{LINK_PATREON} or #{LINK_KOFI}. Thank you so much in advance!",
              txt3:    "Thank you for your generosity!",
              txt4:    "Sincerely,"
            }
          }

        }.freeze
      end
    end
  end
end
