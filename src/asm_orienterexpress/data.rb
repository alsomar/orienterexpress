module ASM_Extensions
  module OrienterExpress

    @dialog = nil # Settings dialog

    MESSAGES = {
      no_selection: "Please select one or more groups/components.",
      no_entities: "Please select at least a group/component."
    }.freeze

    DEBUG = true

    def self.debug_log(source, msg)
      puts "[#{Time.now.strftime('%H:%M:%S')}][#{source}] #{msg}" if DEBUG
    end

    # Filters the input and returns only groups and components
    def self.instances(e)
      e.grep(Sketchup::Group).concat(e.grep(Sketchup::ComponentInstance))
    end
    
    # METHODS

    def self.dynamic_component?(entity)
      return false unless entity.respond_to?(:attribute_dictionary)

      entity.attribute_dictionary("dynamic_attributes") ||
        (entity.respond_to?(:definition) &&
        entity.definition.attribute_dictionary("dynamic_attributes"))
    end

    def self.fix_dc(entity)
      begin
        require 'su_dynamiccomponents'
      rescue LoadError
      end

      return unless defined?($dc_observers)
      
      dc = $dc_observers.get_latest_class
      return unless dc

      return unless dynamic_component?(entity)

      # FASE 2: construir lista de instancias a redibujar
      instances = [entity]

      # Opcional: incluir DCs hijos dentro de la entidad
      if entity.respond_to?(:entities)
        entity.entities.grep(Sketchup::ComponentInstance).each do |inst|
          instances << inst if dynamic_component?(inst)
        end
      end

      instances.each { |inst| dc.method(:redraw).call(inst, true, false) }
    end

    def self.check_selection(edges, targets)
      mt_name = __method__

      if targets.empty? || edges.empty?
        missing = []
        missing << "entities" if targets.empty?
        missing << "edges"   if edges.empty?

        UI.messagebox(MESSAGES[:invalid_sel])
        debug_log(mt_name, "Invalid selection: missing #{missing.join(' & ')}") if DEBUG
        return false
      end

      true
    end

    # Scales the entity along the Z-axis based on the length of each edge
    def self.z_scale(entity, edge)
      scale_factor = edge.length / entity.bounds.depth
      transformation = Geom::Transformation.scaling(entity.definition.bounds.center, 1, 1, scale_factor)
      
      if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        entity.transform!(transformation)
      end
    end
    
    # Applies uniform scaling to match Z-lengh and the edge length
    def self.uniform_scale(entity, edge)
      scale_factor = edge.length / entity.bounds.depth
      transformation = Geom::Transformation.scaling(entity.definition.bounds.center, scale_factor, scale_factor, scale_factor)
      
      if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        entity.transform!(transformation)
      end

    end

    def self.create_entity_copy(entity)
      model = Sketchup.active_model
      model.active_entities.add_instance(entity.definition, entity.transformation)
    end

    def self.align_axis(entity, global_center, local_axis, target_axis, rotation_axis = nil)
      # Compute the angle between the current axis and the target axis
      angle = local_axis.angle_between(target_axis)
      return if angle.abs < 1e-6  # Skip if axes are already aligned

      # Determine the rotation axis
      rotation_axis ||= local_axis.cross(target_axis)
      return if rotation_axis.length.zero?  # Cannot rotate around a zero-length vector

      # Build and apply the rotation transformation
      rotation_transformation = Geom::Transformation.rotation(global_center, rotation_axis, angle)
      entity.transform!(rotation_transformation)
    end

    def self.orient_y(entity, edge)
      # Get the local transformation and axes of the entity
      transformation  = entity.transformation
      z_axis          = transformation.zaxis  # Local Z axis (used as rotation axis)
      y_axis          = transformation.yaxis  # Local Y axis (to be aligned with global XY)
      tolerance       = 1e-6                  # Threshold to skip negligible rotations

      # Sanity checks
      return if z_axis.length < tolerance
      return if y_axis.length < tolerance

      z_axis = z_axis.clone.normalize
      y_axis = y_axis.clone.normalize

      # We want to rotate around z_axis so that y_axis becomes parallel to the global XY plane
      # i.e. y_axis.z → 0

      # Precompute some helpers
      cross = z_axis * y_axis      # cross product
      a = y_axis.z                 # current Z component of local Y (in world space)
      b = cross.z                  # Z component of z_axis × y_axis

      # If Y is already almost parallel to XY, do nothing
      return if a.abs < tolerance && b.abs < tolerance

      # Solve for the angle θ such that the rotated Y has zero Z component:
      # a * cosθ + b * sinθ = 0  =>  tanθ = -a / b  =>  θ = atan2(-a, b)
      angle = Math.atan2(-a, b)

      return if angle.abs < tolerance

      center   = entity.bounds.center
      rotation = Geom::Transformation.rotation(center, z_axis, angle)
      entity.transform!(rotation)
    end

    def self.orient_z(instance, edge)
      # Get the start and end points of the edge
      start_point = edge.start.position
      end_point   = edge.end.position

      # Compute the edge direction vector
      edge_vector = (end_point - start_point)
      return if edge_vector.length < 1e-6  # Skip if the edge is degenerate or has no length

      # Normalize the edge vector to obtain a unit direction
      normal_vector = edge_vector.normalize

      # Extract the instance transformation and world-space data
      transformation = instance.transformation
      origin = transformation.origin          # Pivot point for rotation
      z_axis_world = transformation.zaxis     # Local Z axis expressed in world coordinates

      # Align the instance's Z axis to the edge direction
      align_axis(instance, origin, z_axis_world, normal_vector)
    end

    # Moves the entity to the edge start
    def self.move_to_edge_start(entity, edge)
      entity_origin = entity.transformation.origin
      edge_start = edge.start.position

      translation = Geom::Transformation.translation(edge_start - entity_origin)
      entity.transform!(translation)
    end

    # Moves the entity to the edge center
    def self.move_center2center(entity, edge)
      gc_center_box = entity.bounds.center
      edg_center = Geom::Point3d.linear_combination(0.5, edge.start.position, 0.5, edge.end.position)

      vector_to_edge = edg_center - gc_center_box

      translation = Geom::Transformation.translation(vector_to_edge)
      entity.transform!(translation)
    end

    # Orients the entity to a specific point
    def self.move_to_vertex(entity, point)
      entity_center = entity.bounds.center

      translation = Geom::Transformation.translation(point - entity_center)
      entity.transform!(translation)
    end

    ### MAIN TOOLS ### -----------------------------------------------------------

    def self.oeaxis
      model = Sketchup.active_model
      selection = model.selection

      mt_name = __method__
      start_time = Time.now if DEBUG

      # Selection checks
      edges   = selection.grep(Sketchup::Edge)
      targets = instances(selection)

      return unless check_selection(edges, targets)

      entity = targets.first

      debug_log(mt_name, "-" * 50)
      debug_log(mt_name, "Selection: #{selection.size} element(s)")

      # Operation Start
      op_name = "Orienter Express: Local Origin"
      model.start_operation(op_name, true)
      debug_log(mt_name, "Process START")

      begin
        edges.each do |edge|
          next if edge.length.zero?
          entity_copy = create_entity_copy(entity)
          orient_z(entity_copy, edge)
          orient_y(entity_copy, edge)
          move_to_edge_start(entity_copy, edge)
        end     
        model.commit_operation
        debug_log(mt_name, "Process DONE!")
      rescue => e
        model.abort_operation
        UI.messagebox("Error: #{e.message}")
        debug_log(mt_name, "Process ERROR! #{e.message}")
        debug_log(mt_name, e.backtrace.join("\n"))
      ensure
        model.active_view.refresh
        if DEBUG
          elapsed = Time.now - start_time
          debug_log(mt_name, "Process finished (#{format('%.3f', elapsed)} s)")
        end
      end
    end

    def self.oecenter
      model = Sketchup.active_model
      selection = model.selection

      mt_name = __method__
      start_time = Time.now if DEBUG

      # Selection checks
      edges   = selection.grep(Sketchup::Edge)
      targets = instances(selection)

      return unless check_selection(edges, targets)

      entity = targets.first

      debug_log(mt_name, "-" * 50)
      debug_log(mt_name, "Selection: #{selection.size} element(s)")

      # Operation Start
      op_name = "Orienter Express: Edges Center"
      model.start_operation(op_name, true)
      debug_log(mt_name, "Process START")

      begin
        edges.each do |edge|
          next if edge.length.zero?
          entity_copy = create_entity_copy(entity)
          orient_z(entity_copy, edge)
          orient_y(entity_copy, edge)
          move_center2center(entity_copy, edge)
        end     
        model.commit_operation
        debug_log(mt_name, "Process DONE!")
      rescue => e
        model.abort_operation
        UI.messagebox("Error: #{e.message}")
        debug_log(mt_name, "Process ERROR #{e.message}")
        debug_log(mt_name, e.backtrace.join("\n"))
      ensure
        model.active_view.refresh
        if DEBUG
          elapsed = Time.now - start_time
          debug_log(mt_name, "Elapsed time: #{format('%.3f', elapsed)} sec.")
        end
      end
    end

    def self.oezscale
      model = Sketchup.active_model
      selection = model.selection

      mt_name = __method__
      start_time = Time.now if DEBUG

      # Selection checks
      edges   = selection.grep(Sketchup::Edge)
      targets = instances(selection)

      return unless check_selection(edges, targets)

      entity = targets.first

      debug_log(mt_name, "-" * 50)
      debug_log(mt_name, "Selection: #{selection.size} element(s)")

      # Operation Start
      op_name = "Orienter Express: Z-Scaling"
      model.start_operation(op_name, true)
      debug_log(mt_name, "Process START")

      begin
        edges.each do |edge|
          next if edge.length.zero?
          entity_copy = create_entity_copy(entity)
          z_scale(entity_copy, edge)
          orient_z(entity_copy, edge)
          orient_y(entity_copy, edge)
          move_center2center(entity_copy, edge)
          # fix_dc(entity_copy)
        end
        model.commit_operation
        debug_log(mt_name, "Process DONE!")
      rescue => e
        model.abort_operation
        UI.messagebox("Error: #{e.message}")
        debug_log(mt_name, "Process ERROR #{e.message}")
        debug_log(mt_name, e.backtrace.join("\n"))
      ensure
        model.active_view.refresh
        if DEBUG
          elapsed = Time.now - start_time
          debug_log(mt_name, "Elapsed time: #{format('%.3f', elapsed)} sec.")
        end
      end
    end

    def self.oeuscale
      model = Sketchup.active_model
      selection = model.selection

      mt_name = __method__
      start_time = Time.now if DEBUG

      # Selection checks
      edges   = selection.grep(Sketchup::Edge)
      targets = instances(selection)

      return unless check_selection(edges, targets)

      entity = targets.first

      debug_log(mt_name, "-" * 50)
      debug_log(mt_name, "Selection: #{selection.size} element(s)")

      # Operation Start
      op_name = "Orienter Express: Uniform Scaling"
      model.start_operation(op_name, true)
      debug_log(mt_name, "Process START")

      begin
        edges.each do |edge|
          next if edge.length.zero?
          entity_copy = create_entity_copy(entity)
          uniform_scale(entity_copy, edge)
          orient_z(entity_copy, edge)
          orient_y(entity_copy, edge)
          move_center2center(entity_copy, edge)
        end
        model.commit_operation
        debug_log(mt_name, "Process DONE!")
      rescue => e
        model.abort_operation
        UI.messagebox("Error: #{e.message}")
        debug_log(mt_name, "Process ERROR #{e.message}")
        debug_log(mt_name, e.backtrace.join("\n"))
      ensure
        model.active_view.refresh
        if DEBUG
          elapsed = Time.now - start_time
          debug_log(mt_name, "Elapsed time: #{format('%.3f', elapsed)} sec.")
        end
      end
    end

    def self.oevertex
      model = Sketchup.active_model
      selection = model.selection

      mt_name = __method__
      start_time = Time.now if DEBUG

      # Selection checks
      edges   = selection.grep(Sketchup::Edge)
      targets = instances(selection)

      return unless check_selection(edges, targets)

      entity = targets.first

      debug_log(mt_name, "-" * 50)
      debug_log(mt_name, "Selection: #{selection.size} element(s)")

      # Operation Start
      op_name = "Orienter Express: Vertex Placing"
      model.start_operation(op_name, true)
      debug_log(mt_name, "Process START")

      begin
        vertices = edges.flat_map { |edge| [edge.start.position, edge.end.position] }.uniq { |vertex| vertex.to_a }

        vertices.each do |vertex|
          entity_copy = create_entity_copy(entity)
          move_to_vertex(entity_copy, vertex)
        end
        model.commit_operation
        debug_log(mt_name, "Process DONE!")
      rescue => e
        model.abort_operation
        UI.messagebox("Error: #{e.message}")
        debug_log(mt_name, "Process ERROR #{e.message}")
        debug_log(mt_name, e.backtrace.join("\n"))
      ensure
        model.active_view.refresh
        if DEBUG
          elapsed = Time.now - start_time
          debug_log(mt_name, "Elapsed time: #{format('%.3f', elapsed)} sec.")
        end
      end
    end

    ### EXTRA TOOLS ### ----------------------------------------------------------

    def self.oereset
      model = Sketchup.active_model
      selection = model.selection

      mt_name = __method__
      start_time = Time.now if DEBUG

      # Selection checks
      targets = instances(selection)

      if targets.empty?
        UI.messagebox(MESSAGES[:no_entities])
        debug_log(mt_name, "Invalid selection: missing entities") if DEBUG
        return
      end

      debug_log(mt_name, "-" * 50)
      debug_log(mt_name, "Selection: #{selection.size} element(s)")

      # Operation Start
      op_name = "Orienter Express: Reset Rotations"
      model.start_operation(op_name, true)
      debug_log(mt_name, "Process START")

      begin
        targets.each do |entity|
          center = entity.bounds.center
          transf = entity.transformation

          # Align local Z with global Z
          z_axis  = transf.zaxis
          z_angle = z_axis.angle_between(Z_AXIS)

          if z_angle.abs > 1e-6
            axis_z = z_axis * Z_AXIS
            rot_z  = Geom::Transformation.rotation(center, axis_z, z_angle)
            entity.transform!(rot_z)
            transf = entity.transformation
          end

          # Align local X with global X
          x_axis  = transf.xaxis
          x_angle = x_axis.angle_between(X_AXIS)

          if x_angle.abs > 1e-6
            axis_x = x_axis * X_AXIS
            rot_x  = Geom::Transformation.rotation(center, axis_x, x_angle)
            entity.transform!(rot_x)
          end
        end
        model.commit_operation
        debug_log(mt_name, "Process DONE!")
      rescue => e
        model.abort_operation
        UI.messagebox("Error: #{e.message}")
        debug_log(mt_name, "Process ERROR #{e.message}")
        debug_log(mt_name, e.backtrace.join("\n"))
      ensure
        model.active_view.refresh
        if DEBUG
          elapsed = Time.now - start_time
          debug_log(mt_name, "Elapsed time: #{format('%.3f', elapsed)} sec.")
        end
      end
    end
    
    ### SETTINGS ### -------------------------------------------------------------

    DEFAULT_CONFIG = {
      # General Options
      language: "eng",
      context_menu: false
    }.freeze

    def self.load_config
      if File.exist?(CONFIG_FILE)
        loaded = JSON.parse(File.read(CONFIG_FILE), symbolize_names: true)
        DEFAULT_CONFIG.merge(loaded)
      else
        DEFAULT_CONFIG.dup
      end
    end

    CONTEXT_ON = load_config

    def self.save_config(config_hash)
      begin
        File.write(CONFIG_FILE, JSON.pretty_generate(config_hash))
      rescue => e
        puts "Failed to save config.\n #{e.message}"
      end
    end

    def self.user_settings(settings)
      mt_name = __method__

      current = load_config

      # Filter only the settings that actually changed
      changed = {}

      settings.each do |key, new_value|
        old_value = current[key]
        next if old_value == new_value  # skip if the value is unchanged
        changed[key] = new_value
      end

      if changed.empty?
        debug_log(mt_name, "All values already up-to-date.")
        return
      end

      # Save only the updated settings to the config file
      merged = current.merge(changed)
      save_config(merged)

      # Update the in-memory context only with the changed entries
      CONTEXT_ON.merge!(changed)

      # Log each updated setting on its own line
      changed.each do |key, new_value|
        old_value = current[key]
        debug_log(mt_name, "Setting updated: #{key}: #{new_value.inspect}")
      end
    end

    def self.settings_dialog
      if @dialog && @dialog.visible?
        @dialog.bring_to_front
        return
      end

      html_file  = File.join(PATH_HTML, 'settings.html')
      html_title = "#{PLUGIN_NAME} #{PLUGIN_VERSION}"

      options = {
        dialog_title: html_title,
        preferences_key: "asm_extensions.htmldialog.testextension",
        style: UI::HtmlDialog::STYLE_DIALOG,
        resizable: false,
        width: 420,
        height: 600,
        use_content_size: true
      }

      @dialog = UI::HtmlDialog.new(options)
      @dialog.set_file(html_file)

      # Sends current config to the dialog
      @dialog.add_action_callback("ready") do |_context|
        config = load_config

        @dialog.execute_script("settingsJSON(#{config.to_json.inspect})")
        @dialog.execute_script("infoJSON(#{EXTENSION.to_json.inspect})")
      end

      # Receives updated settings from JS and saves them
      @dialog.add_action_callback("user_settings") do |_context, settings_json|
        settings = JSON.parse(settings_json, symbolize_names: true)
        user_settings(settings)
      end

      @dialog.center
      @dialog.show
    end

  end # Module OrienterExpress
end # Module ASM_Extensions