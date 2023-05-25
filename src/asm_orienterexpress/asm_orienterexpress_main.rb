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
    cmd_axes = UI::Command.new("Oriented copies by local origin") {
      ASM_Extensions::OrienterExpress.orienterexpress_axis
    }
    cmd_axes.tooltip = "Oriented copies by local origin"
    cmd_axes.status_bar_text = "Copy and align a selected group/component along edges, preserving origin and Z-axis alignment."
    cmd_axes.small_icon = self.icon("asm_orienterexpress_axis_16")
    cmd_axes.large_icon = self.icon("asm_orienterexpress_axis_24")
    toolbar = toolbar.add_item cmd_axes

    # Button for orienterexpress_center
    cmd_center = UI::Command.new("Oriented copies by midpoint") {
      ASM_Extensions::OrienterExpress.orienterexpress_center
    }
    cmd_center.tooltip = "Oriented copies by midpoint"
    cmd_center.status_bar_text = "Copy and align a selected group/component along edges, matching the edge midpoints with the boundary box midpoint."
    cmd_center.small_icon = self.icon("asm_orienterexpress_center_16")
    cmd_center.large_icon = self.icon("asm_orienterexpress_center_24")
    toolbar = toolbar.add_item cmd_center

    # Button for orienterexpress_scale_z
    cmd_center = UI::Command.new("Oriented copies by midpoint and Z scale") {
      ASM_Extensions::OrienterExpress.orienterexpress_scale_z
    }
    cmd_center.tooltip = "Oriented copies by midpoint and Z scale"
    cmd_center.status_bar_text = "Copy and align a selected group/component along edges, matching the edge midpoints with the boundary box midpoint and scaling the Z-axis to match the edge length."
    cmd_center.small_icon = self.icon("asm_orienterexpress_scale_z_16")
    cmd_center.large_icon = self.icon("asm_orienterexpress_scale_z_24")
    toolbar = toolbar.add_item cmd_center

    # Button for orienterexpress_scale_xyz
    cmd_center = UI::Command.new("Oriented copies by midpoint and uniform scale") {
      ASM_Extensions::OrienterExpress.orienterexpress_scale_xyz
    }
    cmd_center.tooltip = "Oriented copies by midpoint and uniform scale"
    cmd_center.status_bar_text = "Pace copies Copy and align a selected group/component along edges, matching the edge midpoints with the boundary box midpoint and uniformly scaling to match the edge length."
    cmd_center.small_icon = self.icon("asm_orienterexpress_scale_xyz_16")
    cmd_center.large_icon = self.icon("asm_orienterexpress_scale_xyz_24")
    toolbar = toolbar.add_item cmd_center    

    # Button for orienterexpress_vertex
    cmd_vertex = UI::Command.new("Copies to vertices") {
      ASM_Extensions::OrienterExpress.orienterexpress_vertex
    }
    cmd_vertex.tooltip = "Copies to vertices"
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
    @orienterexpress_menu.add_item("Oriented copies by local origin") { OrienterExpress.orienterexpress_axis }
    @orienterexpress_menu.add_item("Oriented copies by midpoint") { OrienterExpress.orienterexpress_center }
    @orienterexpress_menu.add_item("Oriented copies by midpoint and z scale") { OrienterExpress.orienterexpress_scale_z }
    @orienterexpress_menu.add_item("Oriented copies by midpoint and uniform scale") { OrienterExpress.orienterexpress_scale_xyz }
    @orienterexpress_menu.add_item("Copies to Vertices") { OrienterExpress.orienterexpress_vertex }
    @OrienterExpress_loaded = true
  end 

end # module ASM_Extensions

