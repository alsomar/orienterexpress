module ASM_Extensions
  module OrienterExpress

    ### TRANSFORMATIONS ### -------------------------------------------------------

    # Scales the entity along its local Z-axis to match the edge length.
    # Works correctly regardless of the component's current rotation.
    def self.z_scale(entity, edge)
      return unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)

      local_z_length = entity.transformation.zaxis.length
      return if local_z_length < 1e-6

      local_depth = entity.definition.bounds.depth * local_z_length
      return if local_depth < 1e-6

      scale_factor = edge.length / local_depth
      local_scale  = Geom::Transformation.scaling(entity.definition.bounds.center, 1, 1, scale_factor)
      entity.transformation = entity.transformation * local_scale
    end

    # Applies uniform scaling along the local axes to match Z-length to the edge length.
    # Works correctly regardless of the component's current rotation.
    def self.uniform_scale(entity, edge)
      return unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)

      local_z_length = entity.transformation.zaxis.length
      return if local_z_length < 1e-6

      local_depth = entity.definition.bounds.depth * local_z_length
      return if local_depth < 1e-6

      scale_factor = edge.length / local_depth
      local_scale  = Geom::Transformation.scaling(entity.definition.bounds.center, scale_factor, scale_factor, scale_factor)
      entity.transformation = entity.transformation * local_scale
    end

    def self.create_entity_copy(entity)
      model = Sketchup.active_model
      model.active_entities.add_instance(entity.definition, entity.transformation)
    end

    def self.align_axis(entity, global_center, local_axis, target_axis, rotation_axis = nil)
      angle = local_axis.angle_between(target_axis)
      return if angle.abs < 1e-6

      rotation_axis ||= local_axis.cross(target_axis)
      return if rotation_axis.length.zero?

      rotation_transformation = Geom::Transformation.rotation(global_center, rotation_axis, angle)
      entity.transform!(rotation_transformation)
    end

    def self.orient_y(entity, edge)
      transformation  = entity.transformation
      z_axis          = transformation.zaxis
      y_axis          = transformation.yaxis
      tolerance       = 1e-6

      return if z_axis.length < tolerance
      return if y_axis.length < tolerance

      z_axis = z_axis.clone.normalize
      y_axis = y_axis.clone.normalize

      cross = z_axis * y_axis
      a = y_axis.z
      b = cross.z

      return if a.abs < tolerance && b.abs < tolerance

      angle = Math.atan2(-a, b)
      return if angle.abs < tolerance

      center   = entity.bounds.center
      rotation = Geom::Transformation.rotation(center, z_axis, angle)
      entity.transform!(rotation)
    end

    def self.orient_z(instance, edge)
      start_point = edge.start.position
      end_point   = edge.end.position

      edge_vector = (end_point - start_point)
      return if edge_vector.length < 1e-6

      normal_vector = edge_vector.normalize

      transformation = instance.transformation
      origin         = transformation.origin
      z_axis_world   = transformation.zaxis

      align_axis(instance, origin, z_axis_world, normal_vector)
    end

    def self.move_to_edge_start(entity, edge)
      entity_origin = entity.transformation.origin
      edge_start    = edge.start.position

      translation = Geom::Transformation.translation(edge_start - entity_origin)
      entity.transform!(translation)
    end

    def self.move_center2center(entity, edge)
      gc_center_box = entity.bounds.center
      edg_center    = Geom::Point3d.linear_combination(0.5, edge.start.position, 0.5, edge.end.position)

      vector_to_edge = edg_center - gc_center_box

      translation = Geom::Transformation.translation(vector_to_edge)
      entity.transform!(translation)
    end

    def self.move_to_vertex(entity, point)
      entity_center = entity.bounds.center

      translation = Geom::Transformation.translation(point - entity_center)
      entity.transform!(translation)
    end

    ### MAIN TOOLS ### ------------------------------------------------------------

    def self.oeaxis
      model     = Sketchup.active_model
      selection = model.selection
      method_id = __method__

      edges   = selection.grep(Sketchup::Edge)
      targets = instances(selection)

      return unless check_selection(edges, targets)

      entity = targets.first

      start_time = Time.now if Debug.enabled
      Debug.separator
      Debug.log(self, method_id, "Selection: #{selection.size} element(s)")

      op_name = "Orienter Express: Local Origin"
      model.start_operation(op_name, true)
      Debug.log(self, method_id, "Process START")

      begin
        edges.each do |edge|
          next if edge.length.zero?
          entity_copy = create_entity_copy(entity)
          orient_z(entity_copy, edge)
          orient_y(entity_copy, edge)
          move_to_edge_start(entity_copy, edge)
        end
        model.commit_operation
        Debug.log(self, method_id, "Process DONE!")
      rescue => e
        model.abort_operation
        UI.messagebox("Error: #{e.message}")
        Debug.log(self, method_id, "ERROR #{e.class}: #{e.message}")
        Debug.log(self, method_id, e.backtrace.join("\n"))
      ensure
        model.active_view.refresh
        if Debug.enabled
          elapsed = Time.now - start_time
          Debug.log(self, method_id, "Process DONE! Elapsed #{format('%.3f', elapsed)} sec.")
        end
      end
    end

    def self.oecenter
      model     = Sketchup.active_model
      selection = model.selection
      method_id = __method__

      edges   = selection.grep(Sketchup::Edge)
      targets = instances(selection)

      return unless check_selection(edges, targets)

      entity = targets.first

      start_time = Time.now if Debug.enabled
      Debug.separator
      Debug.log(self, method_id, "Selection: #{selection.size} element(s)")

      op_name = "Orienter Express: Edges Center"
      model.start_operation(op_name, true)
      Debug.log(self, method_id, "Process START")

      begin
        edges.each do |edge|
          next if edge.length.zero?
          entity_copy = create_entity_copy(entity)
          orient_z(entity_copy, edge)
          orient_y(entity_copy, edge)
          move_center2center(entity_copy, edge)
        end
        model.commit_operation
        Debug.log(self, method_id, "Process DONE!")
      rescue => e
        model.abort_operation
        UI.messagebox("Error: #{e.message}")
        Debug.log(self, method_id, "ERROR #{e.class}: #{e.message}")
        Debug.log(self, method_id, e.backtrace.join("\n"))
      ensure
        model.active_view.refresh
        if Debug.enabled
          elapsed = Time.now - start_time
          Debug.log(self, method_id, "Process DONE! Elapsed #{format('%.3f', elapsed)} sec.")
        end
      end
    end

    def self.oezscale
      model     = Sketchup.active_model
      selection = model.selection
      method_id = __method__

      edges   = selection.grep(Sketchup::Edge)
      targets = instances(selection)

      return unless check_selection(edges, targets)

      entity = targets.first

      start_time = Time.now if Debug.enabled
      Debug.separator
      Debug.log(self, method_id, "Selection: #{selection.size} element(s)")

      op_name = "Orienter Express: Z-Scaling"
      model.start_operation(op_name, true)
      Debug.log(self, method_id, "Process START")

      begin
        edges.each do |edge|
          next if edge.length.zero?
          entity_copy = create_entity_copy(entity)
          z_scale(entity_copy, edge)
          orient_z(entity_copy, edge)
          orient_y(entity_copy, edge)
          move_center2center(entity_copy, edge)
        end
        model.commit_operation
        Debug.log(self, method_id, "Process DONE!")
      rescue => e
        model.abort_operation
        UI.messagebox("Error: #{e.message}")
        Debug.log(self, method_id, "ERROR #{e.class}: #{e.message}")
        Debug.log(self, method_id, e.backtrace.join("\n"))
      ensure
        model.active_view.refresh
        if Debug.enabled
          elapsed = Time.now - start_time
          Debug.log(self, method_id, "Process DONE! Elapsed #{format('%.3f', elapsed)} sec.")
        end
      end
    end

    def self.oeuscale
      model     = Sketchup.active_model
      selection = model.selection
      method_id = __method__

      edges   = selection.grep(Sketchup::Edge)
      targets = instances(selection)

      return unless check_selection(edges, targets)

      entity = targets.first

      start_time = Time.now if Debug.enabled
      Debug.separator
      Debug.log(self, method_id, "Selection: #{selection.size} element(s)")

      op_name = "Orienter Express: Uniform Scaling"
      model.start_operation(op_name, true)
      Debug.log(self, method_id, "Process START")

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
        Debug.log(self, method_id, "Process DONE!")
      rescue => e
        model.abort_operation
        UI.messagebox("Error: #{e.message}")
        Debug.log(self, method_id, "ERROR #{e.class}: #{e.message}")
        Debug.log(self, method_id, e.backtrace.join("\n"))
      ensure
        model.active_view.refresh
        if Debug.enabled
          elapsed = Time.now - start_time
          Debug.log(self, method_id, "Process DONE! Elapsed #{format('%.3f', elapsed)} sec.")
        end
      end
    end

    def self.oevertex
      model     = Sketchup.active_model
      selection = model.selection
      method_id = __method__

      edges   = selection.grep(Sketchup::Edge)
      targets = instances(selection)

      return unless check_selection(edges, targets)

      entity = targets.first

      start_time = Time.now if Debug.enabled
      Debug.separator
      Debug.log(self, method_id, "Selection: #{selection.size} element(s)")

      op_name = "Orienter Express: Vertex Placing"
      model.start_operation(op_name, true)
      Debug.log(self, method_id, "Process START")

      begin
        vertices = edges.flat_map { |edge| [edge.start.position, edge.end.position] }.uniq { |v| v.to_a }

        vertices.each do |vertex|
          entity_copy = create_entity_copy(entity)
          move_to_vertex(entity_copy, vertex)
        end
        model.commit_operation
        Debug.log(self, method_id, "Process DONE!")
      rescue => e
        model.abort_operation
        UI.messagebox("Error: #{e.message}")
        Debug.log(self, method_id, "ERROR #{e.class}: #{e.message}")
        Debug.log(self, method_id, e.backtrace.join("\n"))
      ensure
        model.active_view.refresh
        if Debug.enabled
          elapsed = Time.now - start_time
          Debug.log(self, method_id, "Process DONE! Elapsed #{format('%.3f', elapsed)} sec.")
        end
      end
    end

    ### EXTRA TOOLS ### -----------------------------------------------------------

    def self.oereset
      model     = Sketchup.active_model
      selection = model.selection
      method_id = __method__

      targets = instances(selection)

      return unless check_targets(targets)

      start_time = Time.now if Debug.enabled
      Debug.separator
      Debug.log(self, method_id, "Selection: #{selection.size} element(s)")

      op_name = "Orienter Express: Reset Rotations"
      model.start_operation(op_name, true)
      Debug.log(self, method_id, "Process START")

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
        Debug.log(self, method_id, "Process DONE!")
      rescue => e
        model.abort_operation
        UI.messagebox("Error: #{e.message}")
        Debug.log(self, method_id, "ERROR #{e.class}: #{e.message}")
        Debug.log(self, method_id, e.backtrace.join("\n"))
      ensure
        model.active_view.refresh
        if Debug.enabled
          elapsed = Time.now - start_time
          Debug.log(self, method_id, "Process DONE! Elapsed #{format('%.3f', elapsed)} sec.")
        end
      end
    end

  end # module OrienterExpress
end # module ASM_Extensions
