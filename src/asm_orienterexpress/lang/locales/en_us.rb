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
              no_sample_hint:   "Click on a component",
              no_geometry_hint: "Click on an edge or face",
              vcb_hint:         "SHIFT = pivot (%<ip>s)  |  TAB = oriented axis (%<axis>s)  |  ALT = mode (%<mode>s)  |  ← = offset axis (%<offset_axis>s)  |  ↑ = frame (%<frame>s)"
            },
            oecenter: {
              label:            "Edge Center Placement",
              tooltip:          "Edge Center Placement",
              status:           "Place copies centered on edges with an optional offset along the edge.",
              offset_prompt:    "Offset",
              no_sample_hint:   "Click on a component",
              no_geometry_hint: "Click on an edge or face",
              vcb_hint:         "SHIFT = pivot (%<ip>s)  |  TAB = oriented axis (%<axis>s)  |  ALT = mode (%<mode>s)  |  ← = offset axis (%<offset_axis>s)  |  ↑ = frame (%<frame>s)"
            },
            oeaxisscale: {
              label:            "Axis Scaling",
              tooltip:          "Axis Scaling",
              status:           "Scale and place copies along edges with an offset from each vertex.",
              offset_prompt:    "Offset",
              no_sample_hint:   "Click on a component",
              no_geometry_hint: "Click on an edge or face",
              vcb_hint:         "SHIFT = pivot (%<ip>s)  |  TAB = scaled axis (%<axis>s)  |  ALT = mode (%<mode>s)  |  ← = offset axis (%<offset_axis>s)  |  ↑ = frame (%<frame>s)"
            },
            oeuscale: {
              label:            "Uniform Scaling",
              tooltip:          "Uniform Scaling",
              status:           "Scale uniformly and place copies along edges with an offset from each vertex.",
              offset_prompt:    "Offset",
              no_sample_hint:   "Click on a component",
              no_geometry_hint: "Click on an edge or face",
              vcb_hint:         "SHIFT = pivot (%<ip>s)  |  TAB = scaled axis (%<axis>s)  |  ALT = mode (%<mode>s)  |  ← = offset axis (%<offset_axis>s)  |  ↑ = frame (%<frame>s)"
            },
            oeflow: {
              label:            "Vertex Flow Placement",
              tooltip:          "Vertex Flow Placement",
              status:           "Place oriented copies at vertices, aligned to the incoming edge flow.",
              offset_prompt:    "Offset",
              no_sample_hint:   "Click on a component",
              no_geometry_hint: "Click on an edge or face",
              vcb_hint:         "SHIFT = pivot (%<ip>s)  |  TAB = oriented axis (%<axis>s)  |  ALT = mode (%<mode>s)  |  ← = offset axis (%<offset_axis>s)  |  ↑ = frame (%<frame>s)"
            },
            oesurface: {
              label:            "Surface Placement",
              tooltip:          "Surface Placement",
              status:           "Place copies at the center of each smooth surface group, offset along the average normal.",
              offset_prompt:    "Offset",
              no_sample_hint:   "Click on a component",
              no_geometry_hint: "Click on a face",
              vcb_hint:         "SHIFT = pivot (%<ip>s)  |  TAB = oriented axis (%<axis>s)  |  ALT = alignment (%<orient>s)  |  ← = offset axis (%<offset_axis>s)  |  ↑ = frame (%<frame>s)",
              axis_parallel:    "dominant",
              axis_ground:      "horizontal"
            },
            oealigner: {
              label:                     "Axis Aligner",
              tooltip:                   "Axis Aligner",
              status:                    "Aligns the component axes to a face or edge.",
              desc_entity:               "Click on an edge or face of a component or group",
              desc_auto:                 "Click on a component",
              desc_reference_ref:        "Click on a reference edge, face, or component",
              desc_reference_target:     "Click on a component or group",
              vcb_hint_entity:           "CTRL + Click = deep (inner instance)  |  TAB = axis (%<axis>s)  |  ALT = mode (%<mode>s)",
              vcb_hint_auto:             "ALT = mode (%<mode>s)",
              vcb_hint_reference_ref:    "TAB = axis (%<axis>s)  |  ALT = mode (%<mode>s)",
              vcb_hint_reference_target: "CTRL + Click = set new reference  |  TAB = axis (%<axis>s)  |  ALT = mode (%<mode>s)",
              mode_entity:    "entity",
              mode_reference: "reference",
              mode_auto:      "auto",
              axis_z:         "Z",
              axis_x:         "X",
              axis_y:         "Y"
            },
            oereset: {
              label:            "Reset Rotations",
              tooltip:          "Reset Rotations",
              status:           "Reset rotation of selected entities to global axes.",
              no_geometry_hint: "Click on a component",
              vcb_hint:         "TAB = pivot (%<ip>s)  |  ESC = cancel and exit"
            },
            tool_panel: {
              label:   "Tool Panel",
              tooltip: "Tool Panel",
              status:  "Show a floating panel with controls for the active tool.",
              empty:   "No active tool."
            },
            settings: {
              label:   "#{EXT_NAME} Settings",
              tooltip: "#{EXT_NAME} Settings",
              status:  "Open #{EXT_NAME} settings."
            }
          },

          errors: {
            invalid_sel:      "Please select at least one or more edges AND one group/component.",
            invalid_face_sel: "Please select at least one or more faces AND one group/component.",
            no_entities:      "Please select at least one or more groups/components."
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
              center_tool_panel:  "Center tool panel on screen",
              reset_button:       "Show reset button",
              reset_settings:     "Reset settings",
              reset_confirm_body: "This will reset all settings to their default values. Are you sure?",
              reset_confirm_yes:  "Yes, reset",
              reset_confirm_no:   "Cancel",
              rotation_mode:   "Rotation",
              rotation_ground: "Ground",
              rotation_flow:   "Flow",
              rotation_normal: "Normal",
              pivot:              "Pivot",
              pivot_base_short:   "base",
              pivot_center_short: "center",
              pivot_origin_short: "origin",
              axis:               "Orientation axis",
              use_offset:         "Add <strong>position offset</strong>",
              on:                 "On",
              off:                "Off",
              offset_frame:       "Axis frame",
              axes_world:         "World",
              axes_local:         "Local",
              offset_x:           "Offset X",
              offset_y:           "Offset Y",
              offset_z:           "Offset Z",
              offset_alignment:   "Offset tangent",
              offset_normal:      "Offset normal",
              steps:            "Magnitudes",
              roll_step:        "<strong>Roll</strong> increment",
              offset_step:      "<strong>Offset</strong> increment",
              default_roll:     "Default <strong>roll</strong>",
              default_offset_x: "Default <strong>offset X</strong>",
              default_offset_y: "Default <strong>offset Y</strong>",
              default_offset_z: "Default <strong>offset Z</strong>",
              remember_offset:  "Remember <strong>offset</strong>",
              remember_roll:    "Remember <strong>roll</strong>",
              smooth_groups:  "Treat smooth surfaces as a single face"
            },
            tool_panel: {
              title:    "Tools",
              empty:    "empty",
              sample:   "Sample",
              geometry: "Geometry",
              edges:    "%<n>s edges",
              faces:    "%<n>s faces",
              vertices: "%<n>s vertices",
              copies:   "%<n>s copies"
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
