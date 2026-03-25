module ASM_Extensions
  module OrienterExpress

    ### TRANSFORMATIONS ### -------------------------------------------------------

    # Scales the entity along its local Z-axis to match the edge length.
    # Only the Z column of the transformation matrix is modified.
    def self.z_scale(entity, edge)
      return unless instance?(entity)

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
      return unless instance?(entity)

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

    def self.create_entity_copy(definition, transformation)
      Sketchup.active_model.active_entities.add_instance(definition, transformation)
    end

    def self.align_axis(entity, global_center, local_axis, target_axis, rotation_axis = nil)
      return if local_axis.length < 1e-6
      return if target_axis.length < 1e-6

      local_n  = local_axis.normalize
      target_n = target_axis.normalize

      angle = local_n.angle_between(target_n)
      return if angle.abs < 1e-6

      unless rotation_axis
        if angle > Math::PI - 0.01
          # Near-antiparallel (≥ ~179.4°): cross product is numerically unreliable —
          # the residual may exceed the 1e-3 guard and silently suppress the rotation.
          # Pick any perpendicular axis instead.
          rotation_axis = local_n.cross(X_AXIS)
          rotation_axis = local_n.cross(Y_AXIS) if rotation_axis.length < 1e-3
        else
          rotation_axis = local_n.cross(target_n)
        end
      end

      # Use 1e-3 threshold so SketchUp's internal normalization always succeeds.
      return if rotation_axis.length < 1e-3

      rotation_transformation = Geom::Transformation.rotation(global_center, rotation_axis, angle)
      entity.transform!(rotation_transformation)
    end

    # Rotates the entity around its local Z axis so that the local Y axis
    # ends up parallel to the global ground plane.
    def self.orient_y(entity)
      orient_ground(entity, entity.transformation.yaxis)
    end

    # Rotates the entity around its local Z axis so that the local X axis
    # ends up parallel to the global ground plane.
    def self.orient_x(entity)
      orient_ground(entity, entity.transformation.xaxis)
    end

    # Rotates the entity around its local Z axis so that the given local axis
    # ends up parallel to the global ground plane (zero Z component).
    def self.orient_ground(entity, local_axis)
      transformation = entity.transformation
      z_axis         = transformation.zaxis
      tolerance      = 1e-6

      return if z_axis.length < tolerance
      return if local_axis.length < tolerance

      z_axis     = z_axis.normalize
      local_axis = local_axis.normalize

      # When Z is parallel to world Z, all perpendicular axes are already
      # ground-parallel — no rotation needed.
      return if (z_axis.z.abs - 1.0).abs < tolerance

      cross = z_axis * local_axis
      a     = local_axis.z
      b     = cross.z

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

    # For a given vertex, returns the dominant outward direction using three
    # strategies in cascade:
    #   1. Sum of unit vectors from neighbors to vertex (works for asymmetric graphs).
    #   2. Average normal of connected faces (works for symmetric grids on surfaces).
    #   3. Cross product of two non-parallel edge directions (coplanar wireframes).
    # Returns nil if no valid direction can be determined.
    def self.vertex_flow_direction(vertex, edges)
      dirs = []
      edges.each do |edge|
        other = (edge.start == vertex) ? edge.end.position : edge.start.position
        dir   = vertex.position - other
        next if dir.length < 1e-6
        dirs << dir.normalize
      end

      return nil if dirs.empty?

      # 1. Sum of direction vectors.
      sum = Geom::Vector3d.new(dirs.sum(&:x), dirs.sum(&:y), dirs.sum(&:z))
      return sum.normalize if sum.length > 1e-6

      # 2. Vectors cancelled — average normals of connected faces.
      face_normals  = []
      seen_face_ids = {}
      edges.each do |edge|
        edge.faces.each do |face|
          next if seen_face_ids[face.entityID]
          seen_face_ids[face.entityID] = true
          fn = face.normal
          next if fn.length < 1e-6
          fn = fn.normalize
          # Flip to stay consistent with the first normal encountered.
          fn = fn.reverse if !face_normals.empty? && face_normals.first.dot(fn) < 0
          face_normals << fn
        end
      end

      unless face_normals.empty?
        fn_sum = Geom::Vector3d.new(face_normals.sum(&:x), face_normals.sum(&:y), face_normals.sum(&:z))
        return fn_sum.normalize if fn_sum.length > 1e-6
      end

      # 3. Coplanar wireframe — cross product of first two non-parallel edge directions.
      dirs.combination(2) do |a, b|
        cross = a.cross(b)
        return cross.normalize if cross.length > 1e-3
      end

      nil
    end

    ### MAIN TOOLS ### ------------------------------------------------------------

    def self.oeaxis
      model     = Sketchup.active_model
      selection = model.selection
      method_id = __method__

      edges   = edges(selection)
      targets = instances(selection)

      return unless check_selection(edges, targets)

      entity     = targets.first
      entity_def = entity.definition
      entity_t   = entity.transformation

      start_time = Time.now if Debug.enabled
      Debug.separator
      Debug.log(self, method_id, "Selection: #{selection.size} element(s)")

      op_name = "Orienter Express: Local Origin"
      model.start_operation(op_name, true)
      Debug.log(self, method_id, "Process START")

      begin
        edges.each do |edge|
          next if edge.length.zero?
          entity_copy = create_entity_copy(entity_def, entity_t)
          orient_z(entity_copy, edge)
          orient_x(entity_copy)
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

      edges   = edges(selection)
      targets = instances(selection)

      return unless check_selection(edges, targets)

      entity     = targets.first
      entity_def = entity.definition
      entity_t   = entity.transformation

      start_time = Time.now if Debug.enabled
      Debug.separator
      Debug.log(self, method_id, "Selection: #{selection.size} element(s)")

      op_name = "Orienter Express: Edges Center"
      model.start_operation(op_name, true)
      Debug.log(self, method_id, "Process START")

      begin
        edges.each do |edge|
          next if edge.length.zero?
          entity_copy = create_entity_copy(entity_def, entity_t)
          orient_z(entity_copy, edge)
          orient_x(entity_copy)
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

      edges   = edges(selection)
      targets = instances(selection)

      return unless check_selection(edges, targets)

      entity     = targets.first
      entity_def = entity.definition
      entity_t   = entity.transformation

      start_time = Time.now if Debug.enabled
      Debug.separator
      Debug.log(self, method_id, "Selection: #{selection.size} element(s)")

      op_name = "Orienter Express: Z-Scaling"
      model.start_operation(op_name, true)
      Debug.log(self, method_id, "Process START")

      begin
        edges.each do |edge|
          next if edge.length.zero?
          entity_copy = create_entity_copy(entity_def, entity_t)
          z_scale(entity_copy, edge)
          orient_z(entity_copy, edge)
          orient_x(entity_copy)
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

      edges   = edges(selection)
      targets = instances(selection)

      return unless check_selection(edges, targets)

      entity     = targets.first
      entity_def = entity.definition
      entity_t   = entity.transformation

      start_time = Time.now if Debug.enabled
      Debug.separator
      Debug.log(self, method_id, "Selection: #{selection.size} element(s)")

      op_name = "Orienter Express: Uniform Scaling"
      model.start_operation(op_name, true)
      Debug.log(self, method_id, "Process START")

      begin
        edges.each do |edge|
          next if edge.length.zero?
          entity_copy = create_entity_copy(entity_def, entity_t)
          uniform_scale(entity_copy, edge)
          orient_z(entity_copy, edge)
          orient_x(entity_copy)
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

      edges   = edges(selection)
      targets = instances(selection)

      return unless check_selection(edges, targets)

      entity     = targets.first
      entity_def = entity.definition
      entity_t   = entity.transformation

      start_time = Time.now if Debug.enabled
      Debug.separator
      Debug.log(self, method_id, "Selection: #{selection.size} element(s)")

      op_name = "Orienter Express: Vertex Placing"
      model.start_operation(op_name, true)
      Debug.log(self, method_id, "Process START")

      begin
        vertices = edges.flat_map { |edge| [edge.start.position, edge.end.position] }.uniq { |v| v.to_a }

        vertices.each do |vertex|
          entity_copy = create_entity_copy(entity_def, entity_t)
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

      edges   = edges(selection)
      targets = instances(selection)

      return unless check_selection(edges, targets)

      entity     = targets.first
      entity_def = entity.definition
      entity_t   = entity.transformation

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

          entity_copy = create_entity_copy(entity_def, entity_t)
          t           = entity_copy.transformation
          align_axis(entity_copy, t.origin, t.zaxis, direction)
          orient_x(entity_copy)
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

      faces   = faces(selection)
      targets = instances(selection)

      return unless check_face_selection(faces, targets)

      entity     = targets.first
      entity_def = entity.definition
      entity_t   = entity.transformation

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
          entity_copy = create_entity_copy(entity_def, entity_t)
          t           = entity_copy.transformation
          align_axis(entity_copy, t.origin, t.zaxis, normal)
          orient_x(entity_copy)
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
          align_axis(entity, center, entity.transformation.zaxis, Z_AXIS)
          align_axis(entity, center, entity.transformation.xaxis, X_AXIS)
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

    private_class_method :orient_ground
    private_class_method :face_centroid
    private_class_method :vertex_flow_direction

  end # module OrienterExpress
end # module ASM_Extensions
