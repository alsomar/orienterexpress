# frozen_string_literal: true

module ASM_Extensions
  module OrienterExpress
    module Lang
      def self.locale_en_us
        {
          commands: {
            oevertex: {
              label:            "Edge Vertex Placement",
              tooltip:          "Edge Vertex Placement",
              status:           "Place oriented copies at both vertices of each edge, with optional inward offset.",
              offset_prompt:    "Offset",
              no_sample_hint:   "Click a component to use as sample",
              no_geometry_hint: "Click on edges or faces to place copies at their vertices",
              vcb_hint:         "Ctrl: Add geometry to selection  |  Shift: mode (%<mode>s)  |  Tab: insertion point (%<ip>s)  |  ↑: oriented axis (%<axis>s)  |  ↓: roll (%<roll>s)  | Home/End: adjust roll  |  PgUp/PgDn: adjust offset "
            },
            oecenter: {
              label:            "Edge Center Placement",
              tooltip:          "Edge Center Placement",
              status:           "Place copies centered on edges with an optional offset along the edge.",
              offset_prompt:    "Offset",
              no_sample_hint:   "Click a component to use as sample",
              no_geometry_hint: "Click on edges or faces to place copies at their centers",
              vcb_hint:         "Ctrl: Add geometry to selection  |  Shift: mode (%<mode>s)  |  Tab: insertion point (%<ip>s)  |  ↑: oriented axis (%<axis>s)  |  ↓: roll (%<roll>s)  | Home/End: adjust roll  |  PgUp/PgDn: adjust offset"
            },
            oezscale: {
              label:            "Z-axis Scaling",
              tooltip:          "Z-axis Scaling",
              status:           "Scale and place copies along edges with an offset from each vertex.",
              offset_prompt:    "Offset",
              no_sample_hint:   "Click a component to use as sample",
              no_geometry_hint: "Click on edges or faces to scale copies along them",
              vcb_hint:         "Ctrl: Add geometry to selection  |  Shift: mode (%<mode>s)  |  Tab: insertion point (%<ip>s)  |  ↑: scaled axis (%<axis>s)  |  ↓: roll (%<roll>s)  | Home/End: adjust roll  |  PgUp/PgDn: adjust offset"
            },
            oeuscale: {
              label:            "Uniform Scaling",
              tooltip:          "Uniform Scaling",
              status:           "Scale uniformly and place copies along edges.",
              no_sample_hint:   "Click a component to use as sample",
              no_geometry_hint: "Click on edges or faces to scale copies along them",
              vcb_hint:         "Ctrl: Add geometry to selection  |  Shift: mode (%<mode>s)  |  ↓: roll (%<roll>s) | Home/End: adjust roll"
            },
            oeflow: {
              label:            "Vertex Flow Placement",
              tooltip:          "Vertex Flow Placement",
              status:           "Place oriented copies at vertices, aligned to the incoming edge flow.",
              offset_prompt:    "Offset",
              no_sample_hint:   "Click a component to use as sample",
              no_geometry_hint: "Click on edges or faces to place copies at their vertices",
              vcb_hint:         "Ctrl: Add geometry to selection  |  Shift: mode (%<mode>s)  |  Tab: insertion point (%<ip>s)  |  ↑: oriented axis (%<axis>s)  |  ↓: roll (%<roll>s)  | Home/End: adjust roll  |  PgUp/PgDn: adjust offset"
            },
            oeface: {
              label:            "Face Placement",
              tooltip:          "Face Placement",
              status:           "Place copies at face centroids with an offset along the face normal.",
              offset_prompt:    "Offset",
              no_sample_hint:   "Click a component to use as sample",
              no_geometry_hint: "Click on faces to place copies on them",
              vcb_hint:         "Ctrl: Add geometry to selection  |  Shift: orientation (%<orient>s)  |  Tab: insertion point (%<ip>s)  |  ↑: oriented axis (%<axis>s)  |  ↓: roll (%<roll>s)  | Home/End: adjust roll  |  PgUp/PgDn: adjust offset",
              axis_parallel:    "parallel to dominant edge",
              axis_perp:        "perpendicular to dominant edge",
              axis_ground:      "horizontal"
            },
            oealignoptimal: {
              label:    "Optimize Bounding Box",
              tooltip:  "Optimize Bounding Box",
              status:   "Reorients the component axes to minimize the bounding box volume.",
              vcb_hint: "Click: optimize  |  Esc: exit"
            },
            oereset: {
              label:    "Reset Rotations",
              tooltip:  "Reset Rotations",
              status:   "Reset rotation of selected entities to global axes.",
              vcb_hint: "Tab: toggle pivot  |  Esc: cancel"
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
              reset_confirm_no:   "Cancel",
              rotation_mode:   "Rotation",
              rotation_ground: "Ground",
              rotation_flow:   "Flow",
              rotation_normal: "Normal",
              insertion_point:        "Insertion Point",
              insertion_base_short:   "base",
              insertion_center_short: "center",
              insertion_origin_short: "origin"
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
