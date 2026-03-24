module ASM_Extensions
  module OrienterExpress

    ### TRANSFORMATIONS ### -------------------------------------------------------

    # Scales the entity along its local Z-axis to match the edge length.
    # Only the Z column of the transformation matrix is modified.
    def self.z_scale(entity, edge)
      return unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)

      db    = entity.definition.bounds
      def_z = (db.max.z - db.min.z).abs
      return if def_z < 1e-6

      a          = entity.transformation.to_a
      current_sz = Math.sqrt(a[8]**2 + a[9]**2 + a[10]**2)
      return if current_sz < 1e-6

      factor = (edge.length / def_z) / current_sz
      a[8]  *= factor
      a[9]  *= factor
      a[10] *= factor
      entity.transformation = Geom::Transformation.new(a)
    end

    # Scales all axes uniformly so that the Z extent matches the edge length.
    # The ratio between X, Y, Z scales is preserved.
    def self.uniform_scale(entity, edge)
      return unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)

      db    = entity.definition.bounds
      def_z = (db.max.z - db.min.z).abs
      return if def_z < 1e-6

      a          = entity.transformation.to_a
      current_sz = Math.sqrt(a[8]**2 + a[9]**2 + a[10]**2)
      return if current_sz < 1e-6

      factor = (edge.length / def_z) / current_sz
      [0, 1, 2, 4, 5, 6, 8, 9, 10].each { |i| a[i] *= factor }
      entity.transformation = Geom::Transformation.new(a)
    end

    def self.create_entity_copy(entity)
      model = Sketchup.active_model
      model.active_entities.add_instance(entity.definition, entity.transformation)
    end

    def self.align_axis(entity, global_center, local_axis, target_axis, rotation_axis = nil)
      angle = local_axis.angle_between(target_axis)
      return if angle.abs < 1e-6

      rotation_axis ||= local_axis.cross(target_axis)

      if rotation_axis.length < 1e-6
        # Antiparallel case (180°): cross product is undefined, pick any perpendicular axis.
        rotation_axis = local_axis.cross(X_AXIS)
        rotation_axis = local_axis.cross(Y_AXIS) if rotation_axis.length < 1e-6
      end

      return if rotation_axis.length < 1e-6

      rotation_transformation = Geom::Transformation.rotation(global_center, rotation_axis, angle)
      entity.transform!(rotation_transformation)
    end

    # Rotates the entity around its local Z axis so that the local Y axis
    # ends up parallel to the global ground plane (Y component of Z = 0).
    def self.orient_y(entity, _edge)
      transformation  = entity.transformation
      z_axis          = transformation.zaxis
      y_axis          = transformation.yaxis
      tolerance       = 1e-6

      return if z_axis.length < tolerance
      return if y_axis.length < tolerance

      z_axis = z_axis.normalize
      y_axis = y_axis.normalize

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

    # Rotates the entity around its local Z axis so that the local X axis
    # ends up parallel to the global ground plane (X component of Z = 0).
    def self.orient_x(entity, _edge)
      transformation  = entity.transformation
      z_axis          = transformation.zaxis
      x_axis          = transformation.xaxis
      tolerance       = 1e-6

      return if z_axis.length < tolerance
      return if x_axis.length < tolerance

      z_axis = z_axis.normalize
      x_axis = x_axis.normalize

      cross = z_axis * x_axis
      a = x_axis.z
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

    # Moves the entity so the center of its local -Z face (definition space)
    # lands on the given point. Used to place components flush against a surface.
    def self.move_bottom_to(entity, point)
      db           = entity.definition.bounds
      local_bottom = Geom::Point3d.new(db.center.x, db.center.y, db.min.z)
      world_bottom = entity.transformation * local_bottom
      translation  = Geom::Transformation.translation(point - world_bottom)
      entity.transform!(translation)
    end

    # Returns the centroid of a face as the average position of its outer loop vertices.
    def self.face_centroid(face)
      verts = face.outer_loop.vertices
      n = verts.length.to_f
      x = verts.sum { |v| v.position.x } / n
      y = verts.sum { |v| v.position.y } / n
      z = verts.sum { |v| v.position.z } / n
      Geom::Point3d.new(x, y, z)
    end

    # For a given vertex, computes the sum of unit vectors pointing FROM each
    # connected edge's other endpoint TO the vertex. Returns the normalized
    # result, or nil if the vectors cancel out or no valid edges are found.
    def self.vertex_flow_direction(vertex, edges)
      sum_x = 0.0
      sum_y = 0.0
      sum_z = 0.0

      edges.each do |edge|
        other = (edge.start == vertex) ? edge.end.position : edge.start.position
        dir   = vertex.position - other
        next if dir.length < 1e-6

        n      = dir.normalize
        sum_x += n.x
        sum_y += n.y
        sum_z += n.z
      end

      result = Geom::Vector3d.new(sum_x, sum_y, sum_z)
      return nil if result.length < 1e-6

      result.normalize
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
          orient_x(entity_copy, edge)
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
          orient_x(entity_copy, edge)
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
          orient_x(entity_copy, edge)
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
          orient_x(entity_copy, edge)
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

    def self.oeflow
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

      # Group selected edges by their Sketchup::Vertex objects
      vertex_edges = {}
      edges.each do |edge|
        [edge.start, edge.end].each do |vertex|
          vertex_edges[vertex] ||= []
          vertex_edges[vertex] << edge
        end
      end

      op_name = "Orienter Express: Flow Placing"
      model.start_operation(op_name, true)
      Debug.log(self, method_id, "Process START")

      begin
        vertex_edges.each do |vertex, connected|
          direction = vertex_flow_direction(vertex, connected)
          next unless direction

          entity_copy = create_entity_copy(entity)
          t           = entity_copy.transformation
          align_axis(entity_copy, t.origin, t.zaxis, direction)
          orient_x(entity_copy, nil)
          move_to_vertex(entity_copy, vertex.position)
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

    def self.oeface
      model     = Sketchup.active_model
      selection = model.selection
      method_id = __method__

      faces   = selection.grep(Sketchup::Face)
      targets = instances(selection)

      return unless check_face_selection(faces, targets)

      entity = targets.first

      start_time = Time.now if Debug.enabled
      Debug.separator
      Debug.log(self, method_id, "Selection: #{selection.size} element(s)")

      op_name = "Orienter Express: Face Placement"
      model.start_operation(op_name, true)
      Debug.log(self, method_id, "Process START")

      begin
        faces.each do |face|
          normal = face.normal
          next if normal.length < 1e-6

          centroid    = face_centroid(face)
          entity_copy = create_entity_copy(entity)
          t           = entity_copy.transformation
          align_axis(entity_copy, t.origin, t.zaxis, normal)
          orient_x(entity_copy, nil)
          move_bottom_to(entity_copy, centroid)
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

    private_class_method :face_centroid
    private_class_method :vertex_flow_direction

  end # module OrienterExpress
end # module ASM_Extensions
