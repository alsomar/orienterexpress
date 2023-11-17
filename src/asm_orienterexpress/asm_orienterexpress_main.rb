# Please see the loader file for information on the license and author info.
module ASM_Extensions
  module OrienterExpress
    require FILE_DATA

    ICON_EXT = Sketchup.platform == :platform_win ? 'svg' : 'pdf'

    def self.icon(basename)
      File.join(PATH_ICON, "#{basename}.#{ICON_EXT}")
    end

    # Add Toolbar
    toolbar = UI::Toolbar.new "Orienter Express"

    # Button for orienterexpress_axis
    cmd_axes = UI::Command.new("Orienter Express Origin Placement") {
      ASM_Extensions::OrienterExpress.orienterexpress_axis
    }
    cmd_axes.tooltip = "Origin Placement"
    cmd_axes.status_bar_text = "Copy and align a selected group/component along edges, preserving origin and Z-axis alignment."
    cmd_axes.small_icon = self.icon("asm_orienterexpress_axis_16")
    cmd_axes.large_icon = self.icon("asm_orienterexpress_axis_24")
    toolbar = toolbar.add_item cmd_axes

    # Button for orienterexpress_center
    cmd_center = UI::Command.new("Orienter Express Center Placement") {
      ASM_Extensions::OrienterExpress.orienterexpress_center
    }
    cmd_center.tooltip = "Center Placement"
    cmd_center.status_bar_text = "Copy and align a selected group/component along edges, matching the edge midpoints with the boundary box midpoint."
    cmd_center.small_icon = self.icon("asm_orienterexpress_center_16")
    cmd_center.large_icon = self.icon("asm_orienterexpress_center_24")
    toolbar = toolbar.add_item cmd_center

    # Button for orienterexpress_scale_z
    cmd_center = UI::Command.new("Orienter Express Z-axis Scaling") {
      ASM_Extensions::OrienterExpress.orienterexpress_scale_z
    }
    cmd_center.tooltip = "Z-axis Scaling"
    cmd_center.status_bar_text = "Copy and align a selected group/component along edges, matching the edge midpoints with the boundary box midpoint and scaling the Z-axis to match the edge length."
    cmd_center.small_icon = self.icon("asm_orienterexpress_scale_z_16")
    cmd_center.large_icon = self.icon("asm_orienterexpress_scale_z_24")
    toolbar = toolbar.add_item cmd_center

    # Button for orienterexpress_scale_xyz
    cmd_center = UI::Command.new("Orienter Express Uniform Scaling") {
      ASM_Extensions::OrienterExpress.orienterexpress_scale_xyz
    }
    cmd_center.tooltip = "Uniform Scaling"
    cmd_center.status_bar_text = "Copy and align a selected group/component along edges, matching the edge midpoints with the boundary box midpoint and uniformly scaling to match the edge length."
    cmd_center.small_icon = self.icon("asm_orienterexpress_scale_xyz_16")
    cmd_center.large_icon = self.icon("asm_orienterexpress_scale_xyz_24")
    toolbar = toolbar.add_item cmd_center    

    # Button for orienterexpress_vertex
    cmd_vertex = UI::Command.new("Orienter Express Vertex Placement") {
      ASM_Extensions::OrienterExpress.orienterexpress_vertex
    }
    cmd_vertex.tooltip = "Vertex Placement"
    cmd_vertex.status_bar_text = "Place copies of a selected group/component at selection vertices."
    cmd_vertex.small_icon = self.icon("asm_orienterexpress_vertex_16")
    cmd_vertex.large_icon = self.icon("asm_orienterexpress_vertex_24")
    toolbar = toolbar.add_item cmd_vertex

    toolbar.show
  end # module OrienterExpress

  if !defined?(@orienterexpress_menu_loaded)
    @orienterexpress_menu = UI.menu("Extensions").add_submenu("Orienter Express")
    @orienterexpress_menu_loaded = true
  end

  if !defined?(@OrienterExpress_loaded)
    @orienterexpress_menu.add_item("Origin Placement") { OrienterExpress.orienterexpress_axis }
    @orienterexpress_menu.add_item("Center Placement") { OrienterExpress.orienterexpress_center }
    @orienterexpress_menu.add_item("Z-axis Scaling") { OrienterExpress.orienterexpress_scale_z }
    @orienterexpress_menu.add_item("Uniform Scaling") { OrienterExpress.orienterexpress_scale_xyz }
    @orienterexpress_menu.add_item("Vertex Placement") { OrienterExpress.orienterexpress_vertex }
    @orienterexpress_menu.add_separator
    @orienterexpress_menu.add_item("Reset Rotations") { OrienterExpress.orienterexpress_reset_rotations }
    @OrienterExpress_loaded = true
  end 
end # module ASM_Extensions