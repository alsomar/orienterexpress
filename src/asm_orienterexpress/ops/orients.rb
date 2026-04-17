module ASM_Extensions
  module OrienterExpress

    ### TRANSFORMATIONS ### -------------------------------------------------------

    # Scales the entity along its local Z-axis to match the edge length.
    # Only the Z column of the transformation matrix is modified.
    def self.z_scale(entity, edge, target_length = nil)
      return unless instance?(entity)

      db    = entity.definition.bounds
      def_z = (db.max.z - db.min.z).abs
      return if def_z < 1e-6

      a          = entity.transformation.to_a
      current_sz = Math.sqrt(a[8]**2 + a[9]**2 + a[10]**2)
      return if current_sz < 1e-6

      length = target_length || edge.length
      factor = (length / def_z) / current_sz
      a[8]  *= factor
      a[9]  *= factor
      a[10] *= factor
      entity.transformation = Geom::Transformation.new(a)
    end

    # Scales the entity along its local X-axis to match the edge length.
    # Only the X column of the transformation matrix is modified.
    def self.x_scale(entity, edge, target_length = nil)
      return unless instance?(entity)

      db    = entity.definition.bounds
      def_x = (db.max.x - db.min.x).abs
      return if def_x < 1e-6

      a          = entity.transformation.to_a
      current_sx = Math.sqrt(a[0]**2 + a[1]**2 + a[2]**2)
      return if current_sx < 1e-6

      length = target_length || edge.length
      factor = (length / def_x) / current_sx
      a[0] *= factor; a[1] *= factor; a[2] *= factor
      entity.transformation = Geom::Transformation.new(a)
    end

    # Scales the entity along its local Y-axis to match the edge length.
    # Only the Y column of the transformation matrix is modified.
    def self.y_scale(entity, edge, target_length = nil)
      return unless instance?(entity)

      db    = entity.definition.bounds
      def_y = (db.max.y - db.min.y).abs
      return if def_y < 1e-6

      a          = entity.transformation.to_a
      current_sy = Math.sqrt(a[4]**2 + a[5]**2 + a[6]**2)
      return if current_sy < 1e-6

      length = target_length || edge.length
      factor = (length / def_y) / current_sy
      a[4] *= factor; a[5] *= factor; a[6] *= factor
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

    # Rotates the entity around +rotation_axis+ so that +target_axis+ ends up
    # parallel to the global ground plane (zero Z component).
    # Generalization of orient_ground for axes other than local Z.
    def self.orient_ground_around(entity, rotation_axis, target_axis)
      tolerance = 1e-6

      return if rotation_axis.length < tolerance
      return if target_axis.length < tolerance

      rot_axis    = rotation_axis.normalize
      target_norm = target_axis.normalize

      # When the rotation axis is vertical, all perpendicular axes are already
      # ground-parallel — and rotating around a vertical axis cannot change any
      # axis's Z component anyway, so there is nothing useful to do.
      return if (rot_axis.z.abs - 1.0).abs < tolerance

      cross = rot_axis * target_norm
      a     = target_norm.z
      b     = cross.z

      return if a.abs < tolerance && b.abs < tolerance

      angle = Math.atan2(-a, b)
      return if angle.abs < tolerance

      center   = entity.bounds.center
      rotation = Geom::Transformation.rotation(center, rot_axis, angle)
      entity.transform!(rotation)
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

    # Rotates the entity around its local Z axis so that the local Y axis
    # aligns to the average flow direction of the edge's vertices, projected
    # onto the plane perpendicular to Z. Falls back to orient_x if degenerate.
    def self.orient_to_flow(entity, edge, flow_map)
      z_axis     = entity.transformation.zaxis
      flow_start = flow_map[edge.start]
      flow_end   = flow_map[edge.end]
      candidates = [flow_start, flow_end].compact

      if candidates.empty?
        orient_x(entity)
        return
      end

      avg = candidates.reduce(Geom::Vector3d.new(0, 0, 0)) { |s, v| s + v }
      if avg.length < 1e-6
        orient_x(entity)
        return
      end
      avg.normalize!

      # Project onto plane perpendicular to local Z
      dot       = z_axis.dot(avg)
      proj_z    = Geom::Vector3d.new(z_axis.x * dot, z_axis.y * dot, z_axis.z * dot)
      projected = avg - proj_z

      if projected.length < 1e-6
        orient_x(entity)
        return
      end

      target   = projected.normalize
      y_before = entity.transformation.yaxis.normalize

      # Signed angle from y to target around z_axis (right-hand rule).
      # angle_between always returns a positive value, so we compute
      # the sign from the cross product projected onto z_axis.
      dot     = y_before.dot(target)
      cross   = y_before.cross(target)
      sin_val = cross.dot(z_axis.normalize)
      angle   = Math.atan2(sin_val, dot)

      unless angle.abs < 1e-6
        center = entity.bounds.center
        entity.transform!(Geom::Transformation.rotation(center, z_axis, angle))
      end
    end

    # Rotates the entity around its local Z axis so that the local Y axis
    # aligns to the averaged normal of the faces sharing the edge, projected
    # onto the plane perpendicular to Z. Falls back to orient_x if degenerate.
    # For naked vertical edges, orient_x is further refined by h_dir_map so
    # the component faces the wall rather than defaulting to world X.
    def self.orient_to_face_normal(entity, edge, h_dir_map = nil)
      normals = edge.faces.map(&:normal).select { |n| n.length > 1e-6 }.map(&:normalize)
      if normals.empty?
        orient_x(entity)
        # Naked vertical edge: use h_dir_map to orient toward the wall.
        z = entity.transformation.zaxis.normalize
        if (z.z.abs - 1.0).abs < 1e-3
          ref = horizontal_ref_for_vertical_edge(edge, h_dir_map)
          orient_x_to_horizontal(entity, ref) if ref
        end
        return
      end

      avg = normals.reduce(Geom::Vector3d.new(0, 0, 0)) { |s, n| s + n }
      return orient_x(entity) if avg.length < 1e-6
      avg.normalize!

      z_axis = entity.transformation.zaxis
      dot       = z_axis.dot(avg)
      projected = avg - Geom::Vector3d.new(z_axis.x * dot, z_axis.y * dot, z_axis.z * dot)
      return orient_x(entity) if projected.length < 1e-6

      target   = projected.normalize
      y_before = entity.transformation.yaxis.normalize
      cross    = y_before.cross(target)
      sin_val  = cross.dot(z_axis.normalize)
      angle    = Math.atan2(sin_val, y_before.dot(target))

      unless angle.abs < 1e-6
        entity.transform!(Geom::Transformation.rotation(entity.bounds.center, z_axis, angle))
      end
    end

    # Rotates the entity around rot_axis_vec to align face_axis_vec toward the
    # flow direction projected onto the plane perpendicular to rot_axis_vec.
    # Used for X and Y scale axes in flow rotation mode.
    def self.orient_to_flow_around(entity, edge, flow_map, rot_axis_vec, face_axis_vec)
      flow_start = flow_map[edge.start]
      flow_end   = flow_map[edge.end]
      candidates = [flow_start, flow_end].compact

      if candidates.empty?
        orient_x(entity)
        return
      end

      avg = candidates.reduce(Geom::Vector3d.new(0, 0, 0)) { |s, v| s + v }
      if avg.length < 1e-6
        orient_x(entity)
        return
      end
      avg.normalize!

      rot_n     = rot_axis_vec.normalize
      dot       = rot_n.dot(avg)
      projected = avg - Geom::Vector3d.new(rot_n.x * dot, rot_n.y * dot, rot_n.z * dot)

      if projected.length < 1e-6
        orient_x(entity)
        return
      end

      target   = projected.normalize
      f_before = face_axis_vec.normalize
      cross    = f_before.cross(target)
      sin_val  = cross.dot(rot_n)
      angle    = Math.atan2(sin_val, f_before.dot(target))

      unless angle.abs < 1e-6
        entity.transform!(Geom::Transformation.rotation(entity.bounds.center, rot_axis_vec, angle))
      end
    end

    # Rotates entity around rot_axis_vec so that face_axis_vec aligns toward
    # the averaged face normal projected onto the plane perpendicular to rot_axis_vec.
    # Used for X and Y scale axes in normal rotation mode.
    def self.orient_to_face_normal_around(entity, edge, rot_axis_vec, face_axis_vec)
      normals = edge.faces.map(&:normal).select { |n| n.length > 1e-6 }.map(&:normalize)
      return if normals.empty?

      avg = normals.reduce(Geom::Vector3d.new(0, 0, 0)) { |s, n| s + n }
      return if avg.length < 1e-6
      avg.normalize!

      rot_n     = rot_axis_vec.normalize
      dot       = rot_n.dot(avg)
      projected = avg - Geom::Vector3d.new(rot_n.x * dot, rot_n.y * dot, rot_n.z * dot)
      return if projected.length < 1e-6

      target   = projected.normalize
      f_before = face_axis_vec.normalize
      cross    = f_before.cross(target)
      sin_val  = cross.dot(rot_n)
      angle    = Math.atan2(sin_val, f_before.dot(target))

      unless angle.abs < 1e-6
        entity.transform!(Geom::Transformation.rotation(entity.bounds.center, rot_axis_vec, angle))
      end
    end

    # For a vertical edge (local Z ≈ world Z) in ground mode, orient_x is a no-op
    # because every horizontal direction is already ground-parallel.  This method
    # calls orient_x first, then — for vertical edges — tries to find a meaningful
    # horizontal reference for local X:
    #   1. Average face normal projected onto XY.
    #   2. Average of connected-edge XY directions (geometric flow).
    #   3. No rotation (world X remains — current default).
    def self.orient_x_ground(entity, edge = nil, h_dir_map = nil)
      orient_x(entity)
      return unless edge
      z = entity.transformation.zaxis.normalize
      return unless (z.z.abs - 1.0).abs < 1e-3   # only for near-vertical edges
      ref = horizontal_ref_for_vertical_edge(edge, h_dir_map)
      orient_x_to_horizontal(entity, ref) if ref
    end

    # Returns a normalised horizontal (XY) reference vector for a vertical edge.
    # Priority:
    #   0. Propagated map built from full geometry (h_dir_map) — most reliable,
    #      handles symmetric naked-edge meshes where simple averaging cancels.
    #   1. Face normal XY projection.
    #   2. XY average of connected non-self edges (local geometric flow).
    #   Returns nil when all strategies are degenerate.
    def self.horizontal_ref_for_vertical_edge(edge, h_dir_map = nil)
      # 0. Propagated map
      if h_dir_map
        [edge.start, edge.end].each do |v|
          d = h_dir_map[v]
          return d if d   # already normalised XY
        end
      end
      # 1. Face normal XY projection
      normals = edge.faces.map(&:normal).select { |n| n.length > 1e-6 }
      unless normals.empty?
        avg = normals.reduce(Geom::Vector3d.new(0, 0, 0)) { |s, n| s + n }
        ref = Geom::Vector3d.new(avg.x, avg.y, 0)
        return ref.normalize if ref.length > 1e-6
      end
      # 2. XY average of connected non-self edges at both vertices
      sum = Geom::Vector3d.new(0, 0, 0)
      [edge.start, edge.end].each do |vertex|
        vertex.edges.each do |e|
          next if e.equal?(edge)
          other = (e.start == vertex) ? e.end.position : e.start.position
          v     = other - vertex.position
          xy    = Geom::Vector3d.new(v.x, v.y, 0)
          sum   = sum + xy if xy.length > 1e-6
        end
      end
      ref = Geom::Vector3d.new(sum.x, sum.y, 0)
      ref.length > 1e-6 ? ref.normalize : nil
    end

    # Rotates entity around its current Z axis to align local X toward ref_h
    # (only the XY component of ref_h is used).
    def self.orient_x_to_horizontal(entity, ref_h)
      ref_xy = Geom::Vector3d.new(ref_h.x, ref_h.y, 0)
      return if ref_xy.length < 1e-6
      z      = entity.transformation.zaxis.normalize
      x      = entity.transformation.xaxis.normalize
      target = ref_xy.normalize
      angle  = Math.atan2(x.cross(target).dot(z), x.dot(target))
      return if angle.abs < 1e-6
      entity.transform!(Geom::Transformation.rotation(entity.bounds.center, z, angle))
    end

    # Rotates entity around its current X axis to align local Z toward ref_h
    # (only the XY component of ref_h is used). Analogue of orient_x_to_horizontal
    # for scale_axis=X.
    def self.orient_z_to_horizontal(entity, ref_h)
      ref_xy = Geom::Vector3d.new(ref_h.x, ref_h.y, 0)
      return if ref_xy.length < 1e-6
      x      = entity.transformation.xaxis.normalize
      z      = entity.transformation.zaxis.normalize
      target = ref_xy.normalize
      angle  = Math.atan2(z.cross(target).dot(x), z.dot(target))
      return if angle.abs < 1e-6
      entity.transform!(Geom::Transformation.rotation(entity.bounds.center, x, angle))
    end

    # For scale_axis=X in ground mode: makes local Z ground-parallel (by rotating
    # around X), then orients Z toward the face normal / h_dir_map reference.
    # Analogue of orient_x_ground for the X-axis scale case.
    def self.orient_z_ground(entity, edge = nil, h_dir_map = nil)
      orient_ground_around(entity, entity.transformation.xaxis, entity.transformation.zaxis)
      return unless edge
      ref = horizontal_ref_for_vertical_edge(edge, h_dir_map)
      orient_z_to_horizontal(entity, ref) if ref
    end

    # For scale_axis=Y in ground mode: makes local Z ground-parallel (by rotating
    # around Y), then orients Z toward the face normal / h_dir_map reference.
    # Analogue of orient_z_ground but rotates around Y instead of X.
    def self.orient_y_ground(entity, edge = nil, h_dir_map = nil)
      orient_ground_around(entity, entity.transformation.yaxis, entity.transformation.zaxis)
      return unless edge
      ref = horizontal_ref_for_vertical_edge(edge, h_dir_map)
      if ref
        ref_xy = Geom::Vector3d.new(ref.x, ref.y, 0)
        return if ref_xy.length < 1e-6
        y      = entity.transformation.yaxis.normalize
        z      = entity.transformation.zaxis.normalize
        target = ref_xy.normalize
        angle  = Math.atan2(z.cross(target).dot(y), z.dot(target))
        entity.transform!(Geom::Transformation.rotation(entity.bounds.center, y, angle)) if angle.abs > 1e-6
      end
    end

    # Infers a surface normal for a naked edge (no face) for base placement.
    #
    # Near-vertical edges (walls): returns the horizontal XY reference from
    # h_dir_map / connected edges (same direction used for X-axis orientation).
    #
    # Horizontal/oblique edges (floor/ceiling): uses the Z component of the 3D
    # vertex flow direction to determine sign.  A vertex whose connected vertical
    # edges point downward (neighbor above) lies on a bottom surface → normal -Z;
    # one whose vertical edges point upward (neighbor below) lies on a top surface
    # → normal +Z.  Returns nil when the sign is indeterminate (no vertical
    # connectivity), so callers fall back to world +Z.
    def self.naked_edge_surface_normal(edge, h_dir_map = nil, z_sign_map = nil)
      dir = (edge.end.position - edge.start.position).normalize
      if dir.z.abs > 0.7
        # Near-vertical edge → surface is a wall → use horizontal reference.
        horizontal_ref_for_vertical_edge(edge, h_dir_map)
      else
        # Horizontal/oblique edge. Determine whether it belongs to a cap
        # (floor/ceiling) or a lateral ring (vertical wall):
        #   - Cap vertex:    3D flow has significant Z → use ±Z.
        #   - Lateral vertex: 3D flow Z ≈ 0 → surface normal is horizontal
        #                     → use h_dir_map or connected-edge XY average.
        # We compute the DIRECT (non-propagated) flow for both endpoints and
        # pick the first one that gives a clear answer.
        [edge.start, edge.end].each do |vertex|
          d = vertex_flow_direction(vertex, vertex.edges.to_a)
          if d && d.z.abs > 0.3
            # Cap vertex with clear vertical flow → ±Z.
            # Known limitation: rim vertices (where wall meets cap) also fall
            # here and receive ±Z instead of the wall/cap bisector.  Fixing
            # this requires distinguishing rim from interior cap, which proved
            # error-prone when h_dir_map is used as the discriminator (interior
            # cap vertices can appear in h_dir_map via XY flow from asymmetric
            # topology).  Left as a known edge case for naked-edge meshes.
            return Geom::Vector3d.new(0, 0, d.z > 0 ? 1 : -1)
          end
          # Lateral wall vertex or no flow → prefer horizontal reference.
          ref = h_dir_map && h_dir_map[vertex]
          return ref if ref
          # No h_dir_map entry: use propagated ±Z from z_sign_map only when
          # the vertex has no horizontal reference (avoids giving ±Z to wall
          # ring vertices that have an h_dir_map entry).
          next if d && d.z.abs <= 0.3  # has flow but it's lateral — skip z_sign
          ref = z_sign_map && z_sign_map[vertex]
          return ref if ref
        end
        # Last resort: XY geometry of connected edges (works for wall edges).
        horizontal_ref_for_vertical_edge(edge, h_dir_map)
      end
    end

    # Builds a vertex → (0,0,±1) map for horizontal-surface base placement.
    # Vertices connected to vertical edges get their ±Z sign from the 3D flow
    # direction; interior vertices (no vertical connectivity) receive the sign
    # via BFS propagation along all connected edges.
    def self.vertical_surface_directions(vertex_edges)
      reliable = {}
      pending  = {}
      vertex_edges.each_key do |vertex|
        d = vertex_flow_direction(vertex, vertex.edges.to_a)
        if d && d.z.abs > 1e-6
          reliable[vertex] = Geom::Vector3d.new(0, 0, d.z > 0 ? 1 : -1)
        else
          pending[vertex] = true
        end
      end
      queue = reliable.keys.dup
      until queue.empty?
        v   = queue.shift
        dir = reliable[v]
        v.edges.each do |edge|
          neighbor = (edge.start == v) ? edge.end : edge.start
          next unless pending.delete(neighbor)
          reliable[neighbor] = dir
          queue << neighbor
        end
      end
      reliable
    end

    private_class_method :horizontal_ref_for_vertical_edge, :orient_x_to_horizontal,
                         :orient_z_to_horizontal, :orient_z_ground, :orient_y_ground,
                         :naked_edge_surface_normal, :vertical_surface_directions

    # Builds a vertex → normalised XY direction map from a vertex_edges hash.
    # Mirrors all_vertex_flow_directions (same three strategies + BFS sign fix)
    # but projects the final 3D directions onto XY, discarding any result whose
    # XY component is negligible (e.g. vertical normals from flat floor meshes).
    def self.horizontal_flow_directions(vertex_edges)
      reliable   = {}
      candidates = {}

      # Use ALL edges connected to each vertex (not just selected ones) so
      # that corner vertices get their true outward direction from face edges,
      # and strategy 3 can find non-parallel pairs even when only vertical
      # edges were selected.
      vertex_edges.each_key do |vertex|
        all_edges = vertex.edges.to_a
        d = vertex_flow_direction(vertex, all_edges)
        if d
          reliable[vertex] = d
        else
          dirs = []
          all_edges.each do |edge|
            other = (edge.start == vertex) ? edge.end.position : edge.start.position
            dir   = vertex.position - other
            next if dir.length < 1e-6
            dirs << dir.normalize
          end
          dirs.combination(2) do |a, b|
            cross = a.cross(b)
            if cross.length > 1e-3
              candidates[vertex] = cross.normalize
              break
            end
          end
        end
      end

      # BFS: propagate sign from reliable to candidates.
      # Traverse ALL edges connected to each vertex so the signal can reach
      # inner vertices even when only a subset of edges is selected.
      # Only candidates (vertices from the selected geometry) are updated.
      visited = reliable.keys.dup
      queue   = reliable.keys.dup
      until queue.empty?
        v   = queue.shift
        dir = reliable[v]
        v.edges.each do |edge|
          neighbor = (edge.start == v) ? edge.end : edge.start
          next if visited.include?(neighbor)
          next unless candidates.key?(neighbor)
          cross = candidates[neighbor]
          dot   = dir.dot(cross)
          next if dot.abs < 0.1
          reliable[neighbor] = dot >= 0 ? cross : cross.reverse
          candidates.delete(neighbor)
          visited << neighbor
          queue   << neighbor
        end
      end

      # Project to XY; discard entries with negligible horizontal component.
      result = {}
      reliable.merge(candidates).each do |vertex, dir|
        xy = Geom::Vector3d.new(dir.x, dir.y, 0)
        result[vertex] = xy.normalize if xy.length > 1e-6
      end
      result
    end
    private_class_method :horizontal_flow_directions

    # Returns [along, perp]: the longest edge direction and its perpendicular,
    # both lying in the face plane. Returns nil if the face is degenerate.
    def self.face_longest_edge_axes(face)
      longest = face.edges.max_by(&:length)
      return nil unless longest

      dir = longest.end.position - longest.start.position
      return nil if dir.length < 1e-6

      along = dir.normalize
      perp  = face.normal.normalize.cross(along).normalize
      return nil if perp.length < 1e-6

      [along, perp]
    end

    # Rotates entity around its local Z axis so that its X axis aligns to
    # the longest edge direction (axis_idx=0) or its perpendicular (axis_idx=1).
    # Falls back to orient_x if the face is degenerate.
    def self.orient_to_face_edge(entity, face, axis_idx, scale_axis = :z)
      axes = face_longest_edge_axes(face)
      return orient_x(entity) unless axes

      target = axes[axis_idx % 2]
      t      = entity.transformation

      rot_axis  = case scale_axis
                  when :x then t.xaxis.normalize
                  when :y then t.yaxis.normalize
                  else         t.zaxis.normalize
                  end
      face_axis = case scale_axis
                  when :x then t.zaxis.normalize
                  when :y then t.zaxis.normalize
                  else         t.xaxis.normalize
                  end

      dot       = rot_axis.dot(target)
      projected = target - Geom::Vector3d.new(rot_axis.x * dot, rot_axis.y * dot, rot_axis.z * dot)
      return orient_x(entity) if projected.length < 1e-6

      target_n = projected.normalize
      cross    = face_axis.cross(target_n)
      sin_val  = cross.dot(rot_axis)
      angle    = Math.atan2(sin_val, face_axis.dot(target_n))

      unless angle.abs < 1e-6
        entity.transform!(Geom::Transformation.rotation(entity.bounds.center, rot_axis, angle))
      end
    end

    def self.orient_z(instance, edge)
      edge_vector = edge.end.position - edge.start.position
      return if edge_vector.length < 1e-6
      align_axis(instance, instance.transformation.origin,
                 instance.transformation.zaxis, edge_vector.normalize)
    end

    def self.orient_x_to_edge(instance, edge)
      edge_vector = edge.end.position - edge.start.position
      return if edge_vector.length < 1e-6
      align_axis(instance, instance.transformation.origin,
                 instance.transformation.xaxis, edge_vector.normalize)
    end

    def self.orient_y_to_edge(instance, edge)
      edge_vector = edge.end.position - edge.start.position
      return if edge_vector.length < 1e-6
      align_axis(instance, instance.transformation.origin,
                 instance.transformation.yaxis, edge_vector.normalize)
    end

    # Parses a length string, falling back to stripping spaces (SketchUp 2017
    # cannot parse "0 mm" but can parse "0mm"). Returns nil if unparseable.
    def self.parse_length_safe(text)
      result = Sketchup.parse_length(text) rescue nil
      result = Sketchup.parse_length(text.delete(' ')) rescue nil if result.nil?
      # Last resort: plain numeric string stored in CONFIG (value in inches)
      result = text.to_f if result.nil? && text =~ /\A-?[\d.]+\z/
      result
    end

    # Returns a display string for an offset value in the model's current units.
    # Persists the raw numeric value (in inches) to config so it survives unit changes.
    def self.format_and_persist_offset(value, config_key)
      OrienterExpress.user_settings(config_key => value.to_s)
      Sketchup.format_length(value)
    end

    # Reads a persisted offset from CONFIG, converting a raw numeric string if needed.
    def self.load_offset_str(config_key)
      raw = CONFIG[config_key]
      return Sketchup.format_length(0) unless raw
      # If stored as plain number (inches), convert to current model units
      return Sketchup.format_length(raw.to_f) if raw =~ /\A-?[\d.]+\z/
      raw
    end

    # Returns the effective insertion mode for a tool from per-tool config.
    def self.resolved_insertion_point(tool_key)
      custom = CONFIG[:insertion_point_custom]
      (custom.is_a?(Hash) && custom[tool_key]) || 'center'
    end

    # Moves the entity so the given insertion point lands on the target.
    #   insertion_point: :origin, :base, or :center (default)
    #   scale_axis:      :x, :y, or :z/:nil — determines which face is "base"
    #     :x → min-X face center, :y → min-Y face center, else → min-Z face center
    def self.move_insertion_to(entity, point, insertion_point, scale_axis = nil)
      entity_ref = case insertion_point
                   when :origin
                     entity.transformation.origin
                   when :base
                     db         = entity.definition.bounds
                     local_base = case scale_axis
                                  when :x then Geom::Point3d.new(db.min.x, db.center.y, db.center.z)
                                  when :y then Geom::Point3d.new(db.center.x, db.min.y, db.center.z)
                                  else         Geom::Point3d.new(db.center.x, db.center.y, db.min.z)
                                  end
                     entity.transformation * local_base
                   else # :center
                     entity.bounds.center
                   end
      entity.transform!(Geom::Transformation.translation(point - entity_ref))
    end

    # Returns the centroid of a face as the average position of its outer loop vertices.
    def self.face_centroid(face)
      verts = face.outer_loop.vertices
      n = verts.length.to_f
      x = verts.inject(0.0) { |s, v| s + v.position.x } / n
      y = verts.inject(0.0) { |s, v| s + v.position.y } / n
      z = verts.inject(0.0) { |s, v| s + v.position.z } / n
      Geom::Point3d.new(x, y, z)
    end

    # Returns the flow direction for a single vertex using reliable strategies only:
    #   1. Sum of unit vectors from neighbors to vertex (asymmetric nodes).
    #   2. Average normal of connected faces (symmetric nodes on a surface).
    # Returns nil when both strategies cancel out or yield no usable data.
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
      sum = Geom::Vector3d.new(dirs.inject(0.0) { |s, v| s + v.x }, dirs.inject(0.0) { |s, v| s + v.y }, dirs.inject(0.0) { |s, v| s + v.z })
      return sum.normalize if sum.length > 1e-6

      # 2. Average normals of connected faces.
      face_normals  = []
      seen_face_ids = {}
      edges.each do |edge|
        edge.faces.each do |face|
          next if seen_face_ids[face.entityID]
          seen_face_ids[face.entityID] = true
          fn = face.normal
          next if fn.length < 1e-6
          fn = fn.normalize
          fn = fn.reverse if !face_normals.empty? && face_normals.first.dot(fn) < 0
          face_normals << fn
        end
      end

      unless face_normals.empty?
        fn_sum = Geom::Vector3d.new(face_normals.inject(0.0) { |s, v| s + v.x }, face_normals.inject(0.0) { |s, v| s + v.y }, face_normals.inject(0.0) { |s, v| s + v.z })
        return fn_sum.normalize if fn_sum.length > 1e-6
      end

      nil
    end

    # Computes flow directions for every vertex in the map, combining all three
    # strategies and propagating sign from reliable vertices to ambiguous ones.
    #
    # Strategy 3 (cross product of coplanar edges) gives a perpendicular direction
    # but with arbitrary sign. A BFS pass from reliable vertices (strategies 1+2)
    # corrects the sign of any candidate whose plane normal has a measurable
    # component along a neighbouring reliable direction — e.g. cube corners
    # anchoring the orientation of adjacent symmetric faces.
    # Candidates with no reachable reliable neighbour keep their arbitrary sign.
    def self.all_vertex_flow_directions(vertex_edges)
      reliable   = {}   # vertex => direction  (sign is correct)
      candidates = {}   # vertex => direction  (sign may be flipped)

      vertex_edges.each do |vertex, edges|
        d = vertex_flow_direction(vertex, edges)
        if d
          reliable[vertex] = d
        else
          # Strategy 3: coplanar normal — cross product of first non-parallel pair.
          dirs = []
          edges.each do |edge|
            other = (edge.start == vertex) ? edge.end.position : edge.start.position
            dir   = vertex.position - other
            next if dir.length < 1e-6
            dirs << dir.normalize
          end
          dirs.combination(2) do |a, b|
            cross = a.cross(b)
            if cross.length > 1e-3
              candidates[vertex] = cross.normalize
              break
            end
          end
        end
      end

      # BFS: propagate sign from reliable to candidates along shared edges.
      visited = reliable.keys.dup
      queue   = reliable.keys.dup

      until queue.empty?
        v   = queue.shift
        dir = reliable[v]

        vertex_edges[v].each do |edge|
          neighbor = (edge.start == v) ? edge.end : edge.start
          next if visited.include?(neighbor)
          next unless candidates.key?(neighbor)

          cross = candidates[neighbor]
          dot   = dir.dot(cross)
          next if dot.abs < 0.1   # in-plane neighbour — not useful for sign

          reliable[neighbor] = dot >= 0 ? cross : cross.reverse
          candidates.delete(neighbor)
          visited << neighbor
          queue   << neighbor
        end
      end

      reliable.merge(candidates)
    end

    ### MAIN TOOLS ### ------------------------------------------------------------

    # Base class for interactive placement tools (OEVertex, OECenter, OEZScale,
    # OEFlow, OESurface). Handles selection watching, VCB, modifier keys, cursor,
    # click routing, and key repeating. Subclasses implement the placement logic
    # via hook methods: apply, render_vcb, handle_key, on_drag, and others.
    class OEPlacementTool

      # Tracks the currently active placement tool instance so that
      # user_settings changes (e.g. insertion_point from the settings dialog)
      # can be pushed to the running tool without requiring a restart.
      @active_instance = nil
      class << self
        attr_accessor :active_instance
      end

      # Called by OrienterExpress.user_settings when config changes while the
      # tool is running.  Re-reads insertion_point from config if it changed.
      def on_config_changed(changed)
        return unless changed.key?(:insertion_point_custom)
        key = debug_tool_name.to_sym
        new_ip = OrienterExpress.send(:resolved_insertion_point, key).to_sym
        new_ip = :center unless respond_to?(:valid_insertion_points) ?
                                  valid_insertion_points.include?(new_ip) :
                                  %i[center base origin].include?(new_ip)
        return if new_ip == @insertion_point
        @insertion_point = new_ip
        update_vcb
        apply(self.class.last_offset_str)
      end

      class SelectionWatcher < Sketchup::SelectionObserver
        def initialize(&block)
          @callback = block
          @pending  = false
        end

        def onSelectionAdded(_selection, _entity)   schedule end
        def onSelectionRemoved(_selection, _entity) schedule end
        def onSelectionBulkChange(_selection)       schedule end
        def onSelectionCleared(_selection)          schedule end

        private

        def schedule
          return if @pending
          @pending = true
          UI.start_timer(0, false) { @pending = false; @callback.call }
        end
      end

      def initialize(geometry, entity)
        @geometry          = geometry
        @source_entity     = entity
        @entity_def        = entity && entity.definition
        @entity_t          = entity && entity.transformation
        @model             = Sketchup.active_model
        @applied           = false
        @first_apply       = true
        @previous_entities = []
        @placement_map     = {}
        @mod_ctrl          = false
        @mod_shift         = false
      end

      def activate
        @lbutton_down  = false
        @drag_mode     = nil
        @arrow_key_dir = nil
        @roll_key_dir  = nil
        @roll_angle    = CONFIG[:default_roll].to_f.degrees
        @watcher = SelectionWatcher.new { on_external_selection_change }
        @model.selection.add_observer(@watcher)
        OEPlacementTool.active_instance = self
        rebuild_h_dir_map if @rotation_mode != :flow
        update_vcb
        UI.start_timer(0, false) { apply(self.class.last_offset_str); sync_selection } if @entity_def
      end

      def deactivate(view)
        OEPlacementTool.active_instance = nil if OEPlacementTool.active_instance.equal?(self)
        @model.selection.remove_observer(@watcher) if @watcher
        @watcher           = nil
        @applied           = false
        @previous_entities = []
        @placement_map     = {}
        on_deactivate
        view.invalidate
      end

      def resume(view)
        update_vcb
        view.invalidate
      end

      def suspend(view)
        view.invalidate
      end

      def enableVCB?
        true
      end

      def getExtents
        return Geom::BoundingBox.new unless @entity_def && @entity_t
        bb = Geom::BoundingBox.new
        8.times { |i| bb.add(@entity_t * @entity_def.bounds.corner(i)) }
        bb
      end

      def onSetCursor
        update_cursor
      end

      def onLButtonDown(flags, x, y, view)
        @lbutton_down = true
        @syncing = true
        saved = @geometry.dup
        handle_click(flags, x, y, view, :single)
        @geometry = saved if @geometry.empty? && !saved.empty?
        sync_selection
      ensure
        @syncing = false
      end

      def onLButtonDoubleClick(flags, x, y, view)
        @syncing = true
        saved = @geometry.dup
        handle_click(flags, x, y, view, :double)
        @geometry = saved if @geometry.empty? && !saved.empty?
        sync_selection
        @model.close_active while @model.active_path && !@model.active_path.empty?
      ensure
        @syncing = false
      end

      def onLButtonUp(_flags, _x, _y, _view)
        @lbutton_down = false
        @drag_mode    = nil
      end

      def onMouseMove(flags, x, y, view)
        ctrl  = flags & COPY_MODIFIER_MASK      != 0
        shift = flags & CONSTRAIN_MODIFIER_MASK != 0
        if ctrl != @mod_ctrl || shift != @mod_shift
          @mod_ctrl  = ctrl
          @mod_shift = shift
          update_cursor
          view.invalidate
        end
        on_drag(ctrl, shift, view, x, y)
      end

      def onUserText(text, _view)
        stripped = text.strip
        return if stripped.empty?
        if stripped =~ /\A-?\d+([.,]\d+)?\s*(deg|\u00B0)\z/i
          deg = stripped.gsub(',', '.').to_f
          @roll_angle = deg * Math::PI / 180.0
          apply(self.class.last_offset_str)
          update_vcb
        else
          apply(stripped)
        end
      end

      def onKeyDown(key, _repeat, flags, view)
        case key
        when 17 then @mod_ctrl  = true
        when 16 then @mod_shift = true
        when 18 then @alt_handled = false  # reset guard on each new press
        else
          @mod_ctrl  = flags & COPY_MODIFIER_MASK      != 0
          @mod_shift = flags & CONSTRAIN_MODIFIER_MASK != 0
        end
        update_cursor
        view.invalidate
        case key
        when 16 # Shift — cycle insertion point (only when not clicking or combining with Ctrl)
          handle_ins_key unless @lbutton_down || @mod_ctrl
        when 18 # Alt — cycle mode
          handle_mode_key
          @alt_handled = true
        when 27 # Esc
          if @applied
            @model.start_operation(cancel_op_name, true)
            @previous_entities.each { |e| e.erase! if e.valid? }
            @previous_entities = []
            @model.commit_operation
            @applied = false
          end
          @model.select_tool(nil)
        when 37, 39 # Left/Right — adjust offset
          dir = key == 39 ? +1 : -1
          unless @arrow_key_dir == dir
            scroll_offset(dir)
            @arrow_key_dir  = dir
            @key_repeat_gen = (@key_repeat_gen || 0) + 1
            gen = @key_repeat_gen
            UI.start_timer(0.7, false) { key_repeat(dir, gen) }
          end
        when 38, 40 # Up/Down — adjust roll by 15°
          dir = key == 38 ? +1 : -1
          unless @roll_key_dir == dir
            scroll_roll(dir)
            @roll_key_dir      = dir
            @roll_key_rep_gen  = (@roll_key_rep_gen || 0) + 1
            gen = @roll_key_rep_gen
            UI.start_timer(0.7, false) { key_repeat_roll(dir, gen) }
          end
        when 36 # Home — reset offset and roll to defaults
          @roll_angle = CONFIG[:default_roll].to_f.degrees
          update_vcb
          apply(CONFIG[:default_offset].to_s.empty? ? Sketchup.format_length(0) : CONFIG[:default_offset].to_s)
        else
          handle_key(key)
        end
      end

      def onKeyUp(key, _repeat, flags, view)
        case key
        when 17 then @mod_ctrl  = false
        when 16 then @mod_shift = false
        when 18 # Alt — fallback if key-down was swallowed by the OS
          handle_mode_key unless @alt_handled
          @alt_handled = false
        else
          @mod_ctrl  = flags & COPY_MODIFIER_MASK      != 0
          @mod_shift = flags & CONSTRAIN_MODIFIER_MASK != 0
        end
        @arrow_key_dir = nil if key == 37 || key == 39
        @roll_key_dir  = nil if key == 38 || key == 40
        update_cursor
        view.invalidate
      end

      private

      # Hook: tool-specific cleanup on deactivate (e.g. clear @skipped_edges)
      def on_deactivate; end

      # Hook: tool-specific key handling (Tab, etc.)
      def handle_key(_key); end

      # Hook: Alt keypress — cycle scale/orientation axis
      def handle_axis_key; end

      # Hook: Shift keypress — cycle insertion point
      def handle_ins_key; end

      # Hook: Shift keypress without mouse button — cycle rotation mode or equivalent
      def handle_mode_key; end

      # Hook: drag behaviour in onMouseMove
      def on_drag(_ctrl, _shift, _view, _x, _y); end

      # Hook: operation name used when Esc cancels placed entities
      def cancel_op_name
        "Orienter Express: Cancel"
      end

      def update_cursor
        variant = if @mod_ctrl && @mod_shift
                    :minus
                  elsif @mod_ctrl
                    :plus
                  else
                    :default
                  end
        UI.set_cursor(self.class.cursor_id(variant))
      end

      def pick_entity(view, x, y, aperture = 16)
        ph    = view.pick_helper
        count = ph.do_pick(x, y, aperture)
        paths = count.times.map { |i| ph.path_at(i) }
        placed = paths.find { |path| @placement_map.key?(path.first) }
        return placed.first if placed
        root_edge = paths.find { |path| path.first.is_a?(Sketchup::Edge) && path.length == 1 }
        return root_edge.first if root_edge
        ph.best_picked
      end

      # Default: edges from entity (Face → edges, Edge → [edge]).
      # Overridden by OESurfaceTool to return faces.
      def pick_geometry_from_entity(entity)
        case entity
        when Sketchup::Edge then [entity]
        when Sketchup::Face then entity.edges.to_a
        end
      end

      # Default: edge-based flood fill. Overridden by OESurfaceTool.
      def connected_geometry(entity)
        start_items = pick_geometry_from_entity(entity)
        return nil unless start_items
        visited = {}
        queue   = start_items.dup
        until queue.empty?
          edge = queue.pop
          next if visited[edge]
          visited[edge] = true
          [edge.start, edge.end].each { |v| v.edges.each { |e| queue << e unless visited[e] } }
          edge.faces.each { |f| f.edges.each { |e| queue << e unless visited[e] } }
        end
        visited.keys
      end

      def handle_click(flags, x, y, view, click_type)
        ctrl  = flags & COPY_MODIFIER_MASK      != 0
        shift = flags & CONSTRAIN_MODIFIER_MASK != 0
        ph_exact    = view.pick_helper
        count_exact = ph_exact.do_pick(x, y)
        front_instance = count_exact.times.map { |i| ph_exact.path_at(i).first }.find { |e|
          (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)) && !@placement_map.key?(e)
        }
        if front_instance
          pick_new_sample_entity(front_instance)
          return
        end
        handle_geometry_click(ctrl, shift, view, x, y, click_type)
      end

      # Default geometry-click handler (edge tools: Vertex, Center, ZScale).
      # OEFlowTool uses this unchanged; OESurfaceTool overrides it.
      def handle_geometry_click(ctrl, shift, view, x, y, click_type)
        raw  = pick_entity(view, x, y)
        best = @placement_map.key?(raw) ? @placement_map[raw] : raw
        picked = case click_type
                 when :single then pick_geometry_from_entity(best)
                 when :double then connected_geometry(best)
                 end
        mode = if ctrl && shift
                 :remove
               elsif ctrl
                 :add
               else
                 :replace
               end
        @drag_mode = mode unless mode == :replace
        return unless picked
        modify_geometry(mode, picked)
      end

      def modify_geometry(mode, items)
        before = @geometry.to_set
        case mode
        when :add     then @geometry = (@geometry + items).uniq
        when :remove  then @geometry = @geometry - items
        when :replace then @geometry = items.uniq
        end
        return if @geometry.to_set == before
        on_geometry_changed
        apply(self.class.last_offset_str)
        sync_selection
      end

      # Hook: called after geometry set changes (e.g. rebuild flow map).
      # Base implementation rebuilds the horizontal-direction map for ground mode.
      def on_geometry_changed
        rebuild_h_dir_map if @rotation_mode != :flow
      end

      def key_repeat(dir, gen)
        return unless @arrow_key_dir == dir && @key_repeat_gen == gen
        scroll_offset(dir)
        UI.start_timer(0.03, false) { key_repeat(dir, gen) }
      end

      def key_repeat_roll(dir, gen)
        return unless @roll_key_dir == dir && @roll_key_rep_gen == gen
        scroll_roll(dir)
        UI.start_timer(0.03, false) { key_repeat_roll(dir, gen) }
      end

      def scroll_roll(direction)
        step = [CONFIG[:roll_step].to_f, 1.0].max
        @roll_angle = (@roll_angle + direction * step.degrees) % 360.degrees
        @roll_angle = 0.0 if @roll_angle < 1e-9
        apply(self.class.last_offset_str)
        update_vcb
      end

      def scroll_offset(direction)
        current = OrienterExpress.send(:parse_length_safe, self.class.last_offset_str)
        return unless current
        step    = Sketchup.parse_length(CONFIG[:offset_step].to_s) rescue Sketchup.parse_length("1cm")
        new_val = current + direction * step
        apply(Sketchup.format_length(new_val))
        update_vcb
      end

      def on_external_selection_change
        return if @syncing
        new_geometry = collect_geometry_from_selection(@model.selection)
        return if new_geometry.to_set == @geometry.to_set
        old_set      = @geometry.to_set
        new_set      = new_geometry.to_set
        @geometry    = new_geometry
        return unless @entity_def
        @syncing = true
        on_selection_changed(new_set, old_set)
        sync_selection
      ensure
        @syncing = false
      end

      # Hook: collect geometry items from the current selection.
      # Overridden by OESurfaceTool to collect faces instead of edges.
      def collect_geometry_from_selection(selection)
        (selection.grep(Sketchup::Edge) +
         selection.grep(Sketchup::Face).flat_map(&:edges)).uniq.select(&:valid?)
      end

      # Hook: react to an external selection change when entity_def is set.
      # Default does a full re-apply; edge tools override to use apply_diff.
      def on_selection_changed(_new_set, _old_set)
        apply(self.class.last_offset_str)
      end

      def sync_selection
        valid_items = @geometry.select(&:valid?)
        source      = (@source_entity && @source_entity.valid?) ? [@source_entity] : []
        target      = (valid_items + source).to_set
        current     = @model.selection.to_a.to_set
        to_remove   = (current - target).to_a
        to_add      = (target - current).to_a
        @model.selection.remove(to_remove) unless to_remove.empty?
        @model.selection.add(to_add)       unless to_add.empty?
      end

      def update_vcb
        unless @entity_def
          Sketchup.set_status_text("", 1)
          Sketchup.set_status_text("", 2)
          Sketchup.set_status_text(no_sample_hint, 0)
          return
        end
        render_vcb
      end

      # Hook: fill in VCB labels/hints when entity_def is set.
      def render_vcb; end

      # Hook: tool name for debug state line (override in subclasses).
      def debug_tool_name; "unknown"; end

      # Logs a compact state line to the Ruby Console when debug_mode is on,
      # but only when the state has actually changed since the last log.
      def debug_state
        return unless Debug.enabled
        parts  = []
        parts << @rotation_mode.to_s          if defined?(@rotation_mode)
        parts << (@insertion_point || :center).to_s
        parts << (@scale_axis || :z).to_s.upcase
        deg = defined?(@roll_angle) ? ((@roll_angle * 180.0 / Math::PI) % 360.0).round(1) : 0.0
        parts << "#{deg}°"
        line = parts.join(" | ")
        return if line == @last_debug_state
        @last_debug_state = line
        Debug.log(self.class, :state, line)
      end

      # Hook: status text when no sample component is selected yet.
      def no_sample_hint;   ""; end

      # Hook: short description shown as prefix when no geometry is selected yet.
      def no_geometry_hint; ""; end

      # Prepends no_geometry_hint as a permanent description before the key hints.
      def build_status(hint_str)
        pfx = no_geometry_hint
        pfx.empty? ? hint_str : "#{pfx}  |  #{hint_str}"
      end

      # Returns the roll axis: the entity axis aligned to the placement direction
      # (edge inward direction or face normal). Follows @scale_axis if defined.
      def roll_axis(entity_copy)
        t = entity_copy.transformation
        case @scale_axis
        when :x then t.xaxis
        when :y then t.yaxis
        else         t.zaxis
        end
      end

      def apply_roll(entity_copy)
        return if @roll_angle.nil? || @roll_angle.abs < 1e-10
        axis = roll_axis(entity_copy)
        # Canonicalize: always treat the axis as if its dominant component is positive.
        # Rotating by -θ around -v = rotating by +θ around v, so the visual direction
        # is the same for all edges regardless of which way SketchUp oriented them.
        n    = axis.normalize
        sign = if    n.x.abs >= n.y.abs && n.x.abs >= n.z.abs then n.x >= 0 ? 1 : -1
                elsif n.y.abs >= n.z.abs                         then n.y >= 0 ? 1 : -1
                else                                                  n.z >= 0 ? 1 : -1
                end
        entity_copy.transform!(
          Geom::Transformation.rotation(entity_copy.bounds.center, axis, @roll_angle * sign)
        )
      end

      def roll_label
        deg = (@roll_angle * 180.0 / Math::PI) % 360.0
        deg_str = (deg % 1.0).abs < 0.05 ? deg.round.to_s : format('%.1f', deg)
        "#{deg_str} deg"
      end

      # Returns which local axis symbol (:x, :y, or nil=z) of entity_copy is
      # most aligned to reference_vec, taking sign into account so that
      # move_insertion_to's min.{axis} always lands on the correct face.
      # Only valid when reference_vec is the direction the scale_axis
      # was originally aligned to (i.e. OESurfaceTool, where scale_axis
      # stays aligned to normal after all orientations).
      def axis_most_aligned_to(entity_copy, reference_vec)
        return @scale_axis unless reference_vec && reference_vec.length > 1e-6
        t   = entity_copy.transformation
        n   = reference_vec.normalize
        x_d = (t.xaxis.normalize.dot(n)).abs
        y_d = (t.yaxis.normalize.dot(n)).abs
        z_d = (t.zaxis.normalize.dot(n)).abs
        if    x_d >= y_d && x_d >= z_d then :x
        elsif y_d >= z_d               then :y
        else                                nil
        end
      end

      # Places entity_copy so the bounding-box face most in the -normal direction
      # (closest to the surface) lands at target. Works regardless of roll steps
      # because it operates entirely in world space.
      def move_base_to_surface(entity_copy, target, surface_normal)
        n   = surface_normal.normalize
        t   = entity_copy.transformation
        db  = entity_copy.definition.bounds
        # Use definition corners transformed to world space (oriented BB, not AABB)
        world_corners = 8.times.map { |i| t * db.corner(i) }
        dot_n = ->(pt) { pt.x * n.x + pt.y * n.y + pt.z * n.z }
        min_proj  = world_corners.map { |p| dot_n.call(p) }.min
        ctr_world = t * db.center
        base_pt   = ctr_world.offset(n, min_proj - dot_n.call(ctr_world))
        entity_copy.transform!(Geom::Transformation.translation(target - base_pt))
      end

      # For edge tools in base mode: use world-space OBB projection so the result
      # is correct at all roll steps (sign-safe).
      # Priority: face normal → naked_edge_surface_normal → +Z (ground/flow only).
      # Normal mode without a face normal falls back to move_insertion_to since
      # there is no reliable surface direction to infer.
      # Other insertion points fall back to move_insertion_to with @scale_axis.
      def place_with_insertion(entity_copy, target, edge_normal_vec = nil, edge = nil)
        if @insertion_point == :base
          surface_dir = edge_normal_vec ||
                        (edge && OrienterExpress.send(:naked_edge_surface_normal, edge, @h_dir_map, @z_sign_map)) ||
                        (@rotation_mode != :normal && Geom::Vector3d.new(0, 0, 1))
          if surface_dir
            move_base_to_surface(entity_copy, target, surface_dir)
          else
            OrienterExpress.send(:move_insertion_to, entity_copy, target, @insertion_point, @scale_axis)
          end
        else
          OrienterExpress.send(:move_insertion_to, entity_copy, target, @insertion_point, @scale_axis)
        end
      end

      # Returns the averaged face normal for an edge, or nil if the edge has no faces.
      def avg_face_normal_for_edge(edge)
        normals = edge.faces.map(&:normal).select { |n| n.length > 1e-6 }
        return nil if normals.empty?
        avg = normals.reduce(Geom::Vector3d.new(0, 0, 0)) { |s, n| s + n }
        avg.length > 1e-6 ? avg.normalize : nil
      end

      def pick_new_sample_entity(entity)
        @source_entity = entity
        @entity_def    = entity.definition
        @entity_t      = entity.transformation
        @model.start_operation("Orienter Express: Change Sample", true, false, false)
        @previous_entities.each { |e| e.erase! if e.valid? }
        @previous_entities = []
        @model.commit_operation
        @placement_map = {}
        @first_apply   = true
        update_cursor
        update_vcb
        apply(self.class.last_offset_str)
        sync_selection
      end

      def rebuild_flow_map
        vertex_edges = {}
        @geometry.each do |edge|
          [edge.start, edge.end].each do |v|
            vertex_edges[v] ||= []
            vertex_edges[v] << edge
          end
        end
        @flow_map = OrienterExpress.send(:all_vertex_flow_directions, vertex_edges)
      end

      # Builds @h_dir_map: vertex → normalised XY direction for ground-mode
      # orientation of vertical edges.  Uses horizontal_flow_directions which
      # works purely in XY and propagates reliable directions via BFS to
      # symmetric vertices where simple averaging cancels.
      def rebuild_h_dir_map
        return unless @geometry
        vertex_edges = {}
        @geometry.each do |edge|
          [edge.start, edge.end].each do |v|
            vertex_edges[v] ||= []
            vertex_edges[v] << edge
          end
        end
        @h_dir_map  = OrienterExpress.send(:horizontal_flow_directions, vertex_edges)
        @z_sign_map = OrienterExpress.send(:vertical_surface_directions, vertex_edges)
      end

    end

    # Interactive tool for Edge Vertex Placement.
    # Places two copies per edge (one at each vertex), with the active axis
    # pointing inward along the edge direction, offset along the edge from
    # the vertex. Supports Tab (cycle axis) and End (cycle rotation mode).
    class OEVertexTool < OEPlacementTool

      def self.cursor_id(variant = :default)
        @@cursor_ids ||= {}
        @@cursor_ids[variant] ||= begin
          ext      = Sketchup.platform == :platform_win ? 'svg' : 'pdf'
          filename = variant == :default ? "oe_vertex_32" : "oe_vertex_#{variant}_32"
          path     = File.join(PATH_CURSORS, "#{filename}.#{ext}")
          UI.create_cursor(path, 5, 5)
        end
      end

      def self.last_offset_str
        @@last_offset_str ||= OrienterExpress.send(:load_offset_str, :oevertex_offset)
      end

      def self.last_offset_str=(val)
        @@last_offset_str = val
      end

      def initialize(edges, entity, flow_map, rotation_mode)
        super(edges, entity)
        @flow_map        = flow_map
        @rotation_mode   = rotation_mode
        @scale_axis      = :z
        @insertion_point = OrienterExpress.send(:resolved_insertion_point, :oevertex).to_sym
      end

      def activate
        @skipped_edges = []
        super
      end

      def draw(view)
        return if @skipped_edges.nil? || @skipped_edges.empty?
        eye = view.camera.eye
        view.line_width = 4
        view.drawing_color = Sketchup::Color.new(255, 0, 0)
        @skipped_edges.each do |edge|
          next unless edge.valid?
          p1 = edge.start.position.offset((eye - edge.start.position).normalize, 0.1)
          p2 = edge.end.position.offset((eye - edge.end.position).normalize, 0.1)
          view.draw(GL_LINES, [p1, p2])
        end
      end

      def onMouseMove(flags, x, y, view)
        super
        view.invalidate unless @skipped_edges.nil? || @skipped_edges.empty?
      end

      private

      def on_deactivate
        @skipped_edges = []
      end

      def on_drag(ctrl, shift, view, x, y)
        return unless @lbutton_down && @drag_mode && ctrl
        entity = pick_entity(view, x, y, 16)
        entity = @placement_map[entity] if entity && @placement_map.key?(entity)
        picked = pick_geometry_from_entity(entity)
        modify_geometry(@drag_mode, picked) if picked
      end

      def on_geometry_changed
        rebuild_flow_map if @rotation_mode == :flow
        super
      end

      def on_selection_changed(new_set, old_set)
        if @rotation_mode == :flow
          rebuild_flow_map
          apply(OEVertexTool.last_offset_str)
        else
          rebuild_h_dir_map if @rotation_mode != :flow
          offset = OrienterExpress.send(:parse_length_safe, OEVertexTool.last_offset_str)
          apply_diff((new_set - old_set).to_a, (old_set - new_set).to_a, offset)
        end
      end

      def sync_selection
        valid_edges = @geometry.select(&:valid?)
        edge_set    = valid_edges.to_set
        full_faces  = valid_edges.flat_map(&:faces).uniq.select { |f|
          f.valid? && f.edges.all? { |e| edge_set.include?(e) }
        }
        source    = (@source_entity && @source_entity.valid?) ? [@source_entity] : []
        target    = (valid_edges + full_faces + source).to_set
        current   = @model.selection.to_a.to_set
        to_remove = (current - target).to_a
        to_add    = (target - current).to_a
        @model.selection.remove(to_remove) unless to_remove.empty?
        @model.selection.add(to_add)       unless to_add.empty?
      end

      def cancel_op_name
        "Cancel Edge Vertex Placement"
      end

      def handle_key(key)
        case key
        when 9 # Tab — cycle axis
          handle_axis_key
        end
      end

      def handle_axis_key
        @scale_axis  = { z: :x, x: :y, y: :z }[@scale_axis]
        @first_apply = true
        update_vcb
        apply(OEVertexTool.last_offset_str)
      end

      def handle_ins_key
        @insertion_point = { center: :base, base: :origin, origin: :center }[@insertion_point]
        custom = CONFIG[:insertion_point_custom].dup
        custom[:oevertex] = @insertion_point.to_s
        OrienterExpress.user_settings(insertion_point_custom: custom)
        update_vcb
        apply(OEVertexTool.last_offset_str)
      end

      def handle_mode_key
        @rotation_mode = { ground: :flow, flow: :normal, normal: :ground }[@rotation_mode]
        rebuild_flow_map   if @rotation_mode == :flow
        rebuild_h_dir_map  if @rotation_mode != :flow
        update_vcb
        apply(OEVertexTool.last_offset_str)
      end

      def debug_tool_name;  "oevertex"; end
      def no_sample_hint;   Lang.commands.oevertex.no_sample_hint.to_s;   end
      def no_geometry_hint; Lang.commands.oevertex.no_geometry_hint.to_s; end

      def render_vcb
        mode_key   = { ground: :rotation_ground, flow: :rotation_flow, normal: :rotation_normal }[@rotation_mode]
        mode_label = Lang.t(:html, :settings, mode_key)
        axis_label = @scale_axis.to_s.upcase
        ip_key     = { base: :insertion_base_short, center: :insertion_center_short, origin: :insertion_origin_short }[@insertion_point]
        ip_label   = Lang.t(:html, :settings, ip_key)
        hint = format(Lang.commands.oevertex.vcb_hint.to_s, mode: mode_label, axis: axis_label, ip: ip_label, roll: roll_label, offset: OEVertexTool.last_offset_str)
        Sketchup.set_status_text(Lang.commands.oevertex.offset_prompt.to_s, 1)
        Sketchup.set_status_text(OEVertexTool.last_offset_str, 2)
        Sketchup.set_status_text(build_status(hint), 0)
        debug_state
      end

      def apply(text)
        return unless @entity_def
        offset = OrienterExpress.send(:parse_length_safe, text)
        return if offset.nil?

        transparent = !@first_apply
        @model.start_operation("Orienter Express: Edge Vertex Placement", true, false, transparent)

        begin
          @previous_entities.each { |e| e.erase! if e.valid? }
          @previous_entities = []
          @placement_map     = {}

          @geometry.each { |edge| place_for_edge(edge, offset) }

          @model.commit_operation
          @first_apply   = false
          @applied       = true
          @skipped_edges = []
          formatted = OrienterExpress.send(:format_and_persist_offset, offset, :oevertex_offset)
          OEVertexTool.last_offset_str = formatted
          Sketchup.set_status_text(formatted, 2)
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

      def apply_diff(added, removed, offset)
        return unless offset && @entity_def
        @model.start_operation("Orienter Express: Edge Vertex Placement", true, false, true)
        begin
          removed.each do |edge|
            to_erase = @placement_map.select { |_, e| e == edge }.keys
            to_erase.each { |ent| ent.erase! if ent.valid? }
            to_erase.each { |ent| @previous_entities.delete(ent); @placement_map.delete(ent) }
          end
          added.each { |edge| place_for_edge(edge, offset) }
          @model.commit_operation
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

      def place_for_edge(edge, offset)
        return if edge.length.zero?
        edge_vec = edge.end.position - edge.start.position
        return if edge_vec.length < 1e-6
        edge_dir = edge_vec.normalize
        [
          [edge.start.position, edge_dir],
          [edge.end.position,   edge_dir.reverse]
        ].each do |vertex_pos, inward_dir|
          entity_copy = OrienterExpress.create_entity_copy(@entity_def, @entity_t)
          t = entity_copy.transformation
          case @scale_axis
          when :x then OrienterExpress.send(:align_axis, entity_copy, t.origin, t.xaxis, inward_dir)
          when :y then OrienterExpress.send(:align_axis, entity_copy, t.origin, t.yaxis, inward_dir)
          else         OrienterExpress.send(:align_axis, entity_copy, t.origin, t.zaxis, inward_dir)
          end
          case @rotation_mode
          when :flow
            case @scale_axis
            when :x then OrienterExpress.send(:orient_to_flow_around, entity_copy, edge, @flow_map, entity_copy.transformation.xaxis, entity_copy.transformation.zaxis)
            when :y then OrienterExpress.send(:orient_to_flow_around, entity_copy, edge, @flow_map, entity_copy.transformation.yaxis, entity_copy.transformation.zaxis)
            else         OrienterExpress.send(:orient_to_flow, entity_copy, edge, @flow_map)
            end
          when :normal
            case @scale_axis
            when :x then OrienterExpress.send(:orient_to_face_normal_around, entity_copy, edge, entity_copy.transformation.xaxis, entity_copy.transformation.zaxis)
            when :y then OrienterExpress.send(:orient_to_face_normal_around, entity_copy, edge, entity_copy.transformation.yaxis, entity_copy.transformation.zaxis)
            else         OrienterExpress.send(:orient_to_face_normal, entity_copy, edge, @h_dir_map)
            end
          else # ground
            case @scale_axis
            when :x then OrienterExpress.send(:orient_z_ground, entity_copy, edge, @h_dir_map)
            when :y then OrienterExpress.send(:orient_y_ground, entity_copy, edge, @h_dir_map)
            else         OrienterExpress.send(:orient_x_ground, entity_copy, edge, @h_dir_map)
            end
          end
          target_point = vertex_pos.offset(inward_dir, offset)
          apply_roll(entity_copy)
          edge_normal  = avg_face_normal_for_edge(edge)
          place_with_insertion(entity_copy, target_point, edge_normal, edge)
          @previous_entities << entity_copy
          @placement_map[entity_copy] = edge
        end
      end

    end

    def self.oevertex
      model   = Sketchup.active_model
      edges   = (edges(model.selection) + faces(model.selection).flat_map(&:edges)).uniq
      targets = instances(model.selection)

      rotation_mode = CONFIG[:rotation_mode].to_sym rescue :ground
      rotation_mode = :ground unless %i[ground flow normal].include?(rotation_mode)
      flow_map = {}
      if rotation_mode == :flow
        vertex_edges = {}
        edges.each do |edge|
          [edge.start, edge.end].each do |v|
            vertex_edges[v] ||= []
            vertex_edges[v] << edge
          end
        end
        flow_map = all_vertex_flow_directions(vertex_edges)
      end

      entity = targets.first
      model.select_tool(
        OEVertexTool.new(edges, entity, flow_map, rotation_mode)
      )
    end

    # Interactive tool for Edge Center Placement.
    # Places a copy of the component at the midpoint of each selected edge,
    # offset along the edge direction. Supports Tab (cycle axis) and
    # End (cycle rotation mode), identical to OEZScaleTool but without scaling.
    class OECenterTool < OEPlacementTool

      def self.cursor_id(variant = :default)
        @@cursor_ids ||= {}
        @@cursor_ids[variant] ||= begin
          ext      = Sketchup.platform == :platform_win ? 'svg' : 'pdf'
          filename = variant == :default ? "oe_center_32" : "oe_center_#{variant}_32"
          path     = File.join(PATH_CURSORS, "#{filename}.#{ext}")
          UI.create_cursor(path, 5, 5)
        end
      end

      def self.last_offset_str
        @@last_offset_str ||= OrienterExpress.send(:load_offset_str, :oecenter_offset)
      end

      def self.last_offset_str=(val)
        @@last_offset_str = val
      end

      def initialize(edges, entity, flow_map, rotation_mode)
        super(edges, entity)
        @flow_map        = flow_map
        @rotation_mode   = rotation_mode
        @scale_axis      = :z
        @insertion_point = OrienterExpress.send(:resolved_insertion_point, :oecenter).to_sym
      end

      def activate
        @skipped_edges = []
        super
      end

      def draw(view)
        return if @skipped_edges.nil? || @skipped_edges.empty?
        eye = view.camera.eye
        view.line_width = 4
        view.drawing_color = Sketchup::Color.new(255, 0, 0)
        @skipped_edges.each do |edge|
          next unless edge.valid?
          p1 = edge.start.position.offset((eye - edge.start.position).normalize, 0.1)
          p2 = edge.end.position.offset((eye - edge.end.position).normalize, 0.1)
          view.draw(GL_LINES, [p1, p2])
        end
      end

      def onMouseMove(flags, x, y, view)
        super
        view.invalidate unless @skipped_edges.nil? || @skipped_edges.empty?
      end

      private

      def on_deactivate
        @skipped_edges = []
      end

      def on_drag(ctrl, shift, view, x, y)
        return unless @lbutton_down && @drag_mode && ctrl
        entity = pick_entity(view, x, y, 16)
        entity = @placement_map[entity] if entity && @placement_map.key?(entity)
        picked = pick_geometry_from_entity(entity)
        modify_geometry(@drag_mode, picked) if picked
      end

      def on_geometry_changed
        rebuild_flow_map if @rotation_mode == :flow
        super
      end

      def on_selection_changed(new_set, old_set)
        if @rotation_mode == :flow
          rebuild_flow_map
          apply(OECenterTool.last_offset_str)
        else
          rebuild_h_dir_map if @rotation_mode != :flow
          offset = OrienterExpress.send(:parse_length_safe, OECenterTool.last_offset_str)
          apply_diff((new_set - old_set).to_a, (old_set - new_set).to_a, offset)
        end
      end

      def sync_selection
        valid_edges = @geometry.select(&:valid?)
        edge_set    = valid_edges.to_set
        full_faces  = valid_edges.flat_map(&:faces).uniq.select { |f|
          f.valid? && f.edges.all? { |e| edge_set.include?(e) }
        }
        source    = (@source_entity && @source_entity.valid?) ? [@source_entity] : []
        target    = (valid_edges + full_faces + source).to_set
        current   = @model.selection.to_a.to_set
        to_remove = (current - target).to_a
        to_add    = (target - current).to_a
        @model.selection.remove(to_remove) unless to_remove.empty?
        @model.selection.add(to_add)       unless to_add.empty?
      end

      def cancel_op_name
        "Cancel Center Placement"
      end

      def handle_key(key)
        case key
        when 9 # Tab — cycle axis
          handle_axis_key
        end
      end

      def handle_axis_key
        @scale_axis  = { z: :x, x: :y, y: :z }[@scale_axis]
        @first_apply = true
        update_vcb
        apply(OECenterTool.last_offset_str)
      end

      def handle_ins_key
        @insertion_point = { center: :base, base: :origin, origin: :center }[@insertion_point]
        custom = CONFIG[:insertion_point_custom].dup
        custom[:oecenter] = @insertion_point.to_s
        OrienterExpress.user_settings(insertion_point_custom: custom)
        update_vcb
        apply(OECenterTool.last_offset_str)
      end

      def handle_mode_key
        @rotation_mode = { ground: :flow, flow: :normal, normal: :ground }[@rotation_mode]
        rebuild_flow_map   if @rotation_mode == :flow
        rebuild_h_dir_map  if @rotation_mode != :flow
        update_vcb
        apply(OECenterTool.last_offset_str)
      end

      def debug_tool_name;  "oecenter"; end
      def no_sample_hint;   Lang.commands.oecenter.no_sample_hint.to_s;   end
      def no_geometry_hint; Lang.commands.oecenter.no_geometry_hint.to_s; end

      def render_vcb
        mode_key   = { ground: :rotation_ground, flow: :rotation_flow, normal: :rotation_normal }[@rotation_mode]
        mode_label = Lang.t(:html, :settings, mode_key)
        axis_label = @scale_axis.to_s.upcase
        ip_key     = { base: :insertion_base_short, center: :insertion_center_short, origin: :insertion_origin_short }[@insertion_point]
        ip_label   = Lang.t(:html, :settings, ip_key)
        hint = format(Lang.commands.oecenter.vcb_hint.to_s, mode: mode_label, axis: axis_label, ip: ip_label, roll: roll_label, offset: OECenterTool.last_offset_str)
        Sketchup.set_status_text(Lang.commands.oecenter.offset_prompt.to_s, 1)
        Sketchup.set_status_text(OECenterTool.last_offset_str, 2)
        Sketchup.set_status_text(build_status(hint), 0)
        debug_state
      end

      def apply(text)
        return unless @entity_def
        offset = OrienterExpress.send(:parse_length_safe, text)
        return if offset.nil?

        transparent = !@first_apply
        @model.start_operation("Orienter Express: Center Placement", true, false, transparent)

        begin
          @previous_entities.each { |e| e.erase! if e.valid? }
          @previous_entities = []
          @placement_map     = {}

          @geometry.each { |edge| place_for_edge(edge, offset) }

          @model.commit_operation
          @first_apply   = false
          @applied       = true
          @skipped_edges = []
          formatted = OrienterExpress.send(:format_and_persist_offset, offset, :oecenter_offset)
          OECenterTool.last_offset_str = formatted
          Sketchup.set_status_text(formatted, 2)
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

      def apply_diff(added, removed, offset)
        return unless offset && @entity_def
        @model.start_operation("Orienter Express: Center Placement", true, false, true)
        begin
          removed.each do |edge|
            to_erase = @placement_map.select { |_, e| e == edge }.keys
            to_erase.each { |ent| ent.erase! if ent.valid? }
            to_erase.each { |ent| @previous_entities.delete(ent); @placement_map.delete(ent) }
          end
          added.each { |edge| place_for_edge(edge, offset) }
          @model.commit_operation
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

      def place_for_edge(edge, offset)
        return if edge.length.zero?
        entity_copy = OrienterExpress.create_entity_copy(@entity_def, @entity_t)
        case @scale_axis
        when :x then OrienterExpress.orient_x_to_edge(entity_copy, edge)
        when :y then OrienterExpress.orient_y_to_edge(entity_copy, edge)
        else         OrienterExpress.orient_z(entity_copy, edge)
        end
        case @rotation_mode
        when :flow
          case @scale_axis
          when :x then OrienterExpress.send(:orient_to_flow_around, entity_copy, edge, @flow_map, entity_copy.transformation.xaxis, entity_copy.transformation.zaxis)
          when :y then OrienterExpress.send(:orient_to_flow_around, entity_copy, edge, @flow_map, entity_copy.transformation.yaxis, entity_copy.transformation.zaxis)
          else         OrienterExpress.send(:orient_to_flow, entity_copy, edge, @flow_map)
          end
        when :normal
          case @scale_axis
          when :x then OrienterExpress.send(:orient_to_face_normal_around, entity_copy, edge, entity_copy.transformation.xaxis, entity_copy.transformation.zaxis)
          when :y then OrienterExpress.send(:orient_to_face_normal_around, entity_copy, edge, entity_copy.transformation.yaxis, entity_copy.transformation.zaxis)
          else         OrienterExpress.send(:orient_to_face_normal, entity_copy, edge, @h_dir_map)
          end
        else # ground
          case @scale_axis
          when :x then OrienterExpress.send(:orient_z_ground, entity_copy, edge, @h_dir_map)
          when :y then OrienterExpress.send(:orient_y_ground, entity_copy, edge, @h_dir_map)
          else         OrienterExpress.send(:orient_x_ground, entity_copy, edge, @h_dir_map)
          end
        end
        edge_vec = edge.end.position - edge.start.position
        midpoint = Geom::Point3d.linear_combination(0.5, edge.start.position, 0.5, edge.end.position)
        midpoint = midpoint.offset(edge_vec.normalize, offset) unless edge_vec.length < 1e-6
        apply_roll(entity_copy)
        edge_normal = avg_face_normal_for_edge(edge)
        place_with_insertion(entity_copy, midpoint, edge_normal, edge)
        @previous_entities << entity_copy
        @placement_map[entity_copy] = edge
      end

    end

    def self.oecenter
      model   = Sketchup.active_model
      edges   = (edges(model.selection) + faces(model.selection).flat_map(&:edges)).uniq
      targets = instances(model.selection)

      rotation_mode = CONFIG[:rotation_mode].to_sym rescue :ground
      rotation_mode = :ground unless %i[ground flow normal].include?(rotation_mode)
      flow_map = {}
      if rotation_mode == :flow
        vertex_edges = {}
        edges.each do |edge|
          [edge.start, edge.end].each do |v|
            vertex_edges[v] ||= []
            vertex_edges[v] << edge
          end
        end
        flow_map = all_vertex_flow_directions(vertex_edges)
      end

      entity = targets.first
      model.select_tool(
        OECenterTool.new(edges, entity, flow_map, rotation_mode)
      )
    end


    # Tool class for interactive Z-Scaling.
    # The user adjusts the offset via the VCB; each Enter re-applies the
    # operation so the result updates in real time.
    # Escape undoes the last preview and exits. Switching tools commits.
    class OEZScaleTool < OEPlacementTool

      def self.cursor_id(variant = :default)
        @@cursor_ids ||= {}
        @@cursor_ids[variant] ||= begin
          ext  = Sketchup.platform == :platform_win ? 'svg' : 'pdf'
          filename = variant == :default ? "oe_zscale_32" : "oe_zscale_#{variant}_32"
          path = File.join(PATH_CURSORS, "#{filename}.#{ext}")
          UI.create_cursor(path, 5, 5)
        end
      end

      def self.last_offset_str
        @@last_offset_str ||= OrienterExpress.send(:load_offset_str, :oezscale_offset)
      end

      def self.last_offset_str=(val)
        @@last_offset_str = val
      end

      def initialize(edges, entity, flow_map, rotation_mode)
        super(edges, entity)
        @flow_map        = flow_map
        @rotation_mode   = rotation_mode
        @scale_axis      = :z
        ip = OrienterExpress.send(:resolved_insertion_point, :oezscale).to_sym
        @insertion_point = [:center, :base].include?(ip) ? ip : :center
      end

      def activate
        @skipped_edges = []
        super
      end

      def draw(view)
        return if @skipped_edges.nil? || @skipped_edges.empty?
        eye = view.camera.eye
        view.line_width = 4
        view.drawing_color = Sketchup::Color.new(255, 0, 0)
        @skipped_edges.each do |edge|
          next unless edge.valid?
          p1 = edge.start.position.offset((eye - edge.start.position).normalize, 0.1)
          p2 = edge.end.position.offset((eye - edge.end.position).normalize, 0.1)
          view.draw(GL_LINES, [p1, p2])
        end
      end

      def onMouseMove(flags, x, y, view)
        super
        view.invalidate unless @skipped_edges.nil? || @skipped_edges.empty?
      end

      private

      def on_deactivate
        @skipped_edges = []
      end

      def on_drag(ctrl, shift, view, x, y)
        return unless @lbutton_down && @drag_mode && ctrl
        entity = pick_entity(view, x, y, 16)
        entity = @placement_map[entity] if entity && @placement_map.key?(entity)
        picked = pick_geometry_from_entity(entity)
        modify_geometry(@drag_mode, picked) if picked
      end

      def on_geometry_changed
        rebuild_flow_map if @rotation_mode == :flow
        super
      end

      def on_selection_changed(new_set, old_set)
        if @rotation_mode == :flow
          rebuild_flow_map
          apply(OEZScaleTool.last_offset_str)
        else
          rebuild_h_dir_map if @rotation_mode != :flow
          offset = OrienterExpress.send(:parse_length_safe, OEZScaleTool.last_offset_str)
          apply_diff((new_set - old_set).to_a, (old_set - new_set).to_a, offset)
        end
      end

      def sync_selection
        valid_edges = @geometry.select(&:valid?)
        edge_set    = valid_edges.to_set
        full_faces  = valid_edges.flat_map(&:faces).uniq.select { |f|
          f.valid? && f.edges.all? { |e| edge_set.include?(e) }
        }
        source    = (@source_entity && @source_entity.valid?) ? [@source_entity] : []
        target    = (valid_edges + full_faces + source).to_set
        current   = @model.selection.to_a.to_set
        to_remove = (current - target).to_a
        to_add    = (target - current).to_a
        @model.selection.remove(to_remove) unless to_remove.empty?
        @model.selection.add(to_add)       unless to_add.empty?
      end

      def cancel_op_name
        "Cancel Z-Scaling"
      end

      def handle_key(key)
        case key
        when 9 # Tab — cycle axis
          handle_axis_key
        end
      end

      def handle_axis_key
        @scale_axis  = { x: :y, y: :z, z: :x }[@scale_axis]
        @first_apply = true
        update_vcb
        apply(OEZScaleTool.last_offset_str)
      end

      def handle_ins_key
        @insertion_point = @insertion_point == :center ? :base : :center
        custom = CONFIG[:insertion_point_custom].dup
        custom[:oezscale] = @insertion_point.to_s
        OrienterExpress.user_settings(insertion_point_custom: custom)
        update_vcb
        apply(OEZScaleTool.last_offset_str)
      end

      def handle_mode_key
        @rotation_mode = { ground: :flow, flow: :normal, normal: :ground }[@rotation_mode]
        rebuild_flow_map   if @rotation_mode == :flow
        rebuild_h_dir_map  if @rotation_mode != :flow
        update_vcb
        apply(OEZScaleTool.last_offset_str)
      end

      def debug_tool_name;        "oezscale"; end
      def valid_insertion_points; %i[center base]; end
      def no_sample_hint;   Lang.commands.oezscale.no_sample_hint.to_s;   end
      def no_geometry_hint; Lang.commands.oezscale.no_geometry_hint.to_s; end

      def render_vcb
        mode_key   = { ground: :rotation_ground, flow: :rotation_flow, normal: :rotation_normal }[@rotation_mode]
        mode_label = Lang.t(:html, :settings, mode_key)
        axis_label = @scale_axis.to_s.upcase
        ip_key     = @insertion_point == :base ? :insertion_base_short : :insertion_center_short
        ip_label   = Lang.t(:html, :settings, ip_key)
        hint = format(Lang.commands.oezscale.vcb_hint.to_s, mode: mode_label, axis: axis_label, ip: ip_label, roll: roll_label, offset: OEZScaleTool.last_offset_str)
        Sketchup.set_status_text(Lang.commands.oezscale.offset_prompt.to_s, 1)
        Sketchup.set_status_text(OEZScaleTool.last_offset_str, 2)
        Sketchup.set_status_text(build_status(hint), 0)
        debug_state
      end

      def apply(text)
        return unless @entity_def
        offset = OrienterExpress.send(:parse_length_safe, text)
        return if offset.nil?

        transparent = !@first_apply
        @model.start_operation("Orienter Express: Z-Scaling", true, false, transparent)

        begin
          @previous_entities.each { |e| e.erase! if e.valid? }
          @previous_entities = []
          @placement_map     = {}
          skipped            = []

          @geometry.each { |edge| place_for_edge(edge, offset, skipped) }

          @model.commit_operation
          @first_apply   = false
          @applied       = true
          @skipped_edges = skipped
          formatted = OrienterExpress.send(:format_and_persist_offset, offset, :oezscale_offset)
          OEZScaleTool.last_offset_str = formatted
          Sketchup.set_status_text(formatted, 2)
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

      def apply_diff(added, removed, offset)
        return unless offset && @entity_def
        @model.start_operation("Orienter Express: Z-Scaling", true, false, true)
        begin
          removed.each do |edge|
            @skipped_edges.delete(edge)
            to_erase = @placement_map.select { |_, e| e == edge }.keys
            to_erase.each { |ent| ent.erase! if ent.valid? }
            to_erase.each { |ent| @previous_entities.delete(ent); @placement_map.delete(ent) }
          end
          added.each { |edge| place_for_edge(edge, offset, @skipped_edges) }
          @model.commit_operation
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

      def place_for_edge(edge, offset, skipped = nil)
        return if edge.length.zero?
        effective_length = edge.length - 2 * offset
        if effective_length <= 1e-6
          skipped << edge if skipped
          return
        end
        entity_copy = OrienterExpress.create_entity_copy(@entity_def, @entity_t)
        case @scale_axis
        when :x
          OrienterExpress.x_scale(entity_copy, edge, effective_length)
          OrienterExpress.orient_x_to_edge(entity_copy, edge)
        when :y
          OrienterExpress.y_scale(entity_copy, edge, effective_length)
          OrienterExpress.orient_y_to_edge(entity_copy, edge)
        else
          OrienterExpress.z_scale(entity_copy, edge, effective_length)
          OrienterExpress.orient_z(entity_copy, edge)
        end
        case @rotation_mode
        when :flow
          case @scale_axis
          when :x then OrienterExpress.send(:orient_to_flow_around, entity_copy, edge, @flow_map, entity_copy.transformation.xaxis, entity_copy.transformation.zaxis)
          when :y then OrienterExpress.send(:orient_to_flow_around, entity_copy, edge, @flow_map, entity_copy.transformation.yaxis, entity_copy.transformation.zaxis)
          else         OrienterExpress.send(:orient_to_flow, entity_copy, edge, @flow_map)
          end
        when :normal
          case @scale_axis
          when :x then OrienterExpress.send(:orient_to_face_normal_around, entity_copy, edge, entity_copy.transformation.xaxis, entity_copy.transformation.zaxis)
          when :y then OrienterExpress.send(:orient_to_face_normal_around, entity_copy, edge, entity_copy.transformation.yaxis, entity_copy.transformation.zaxis)
          else         OrienterExpress.send(:orient_to_face_normal, entity_copy, edge, @h_dir_map)
          end
        else # ground
          case @scale_axis
          when :x then OrienterExpress.send(:orient_z_ground, entity_copy, edge, @h_dir_map)
          when :y then OrienterExpress.send(:orient_y_ground, entity_copy, edge, @h_dir_map)
          else         OrienterExpress.send(:orient_x_ground, entity_copy, edge, @h_dir_map)
          end
        end
        midpoint = Geom::Point3d.linear_combination(0.5, edge.start.position, 0.5, edge.end.position)
        apply_roll(entity_copy)
        if @insertion_point == :base
          # Step 1 — center the component along the scale axis (same as :center mode).
          OrienterExpress.send(:move_insertion_to, entity_copy, midpoint, :center, @scale_axis)
          # Step 2 — project the "up" reference onto the cross-section plane (⊥ to scale axis).
          # All modes use the face normal when available so the base lands on the correct side
          # of the surface (floor, ceiling, wall). Falls back to world +Z for naked edges.
          scale_axis_world = roll_axis(entity_copy).normalize
          ref_up  = avg_face_normal_for_edge(edge)
          ref_up ||= OrienterExpress.send(:naked_edge_surface_normal, edge, @h_dir_map, @z_sign_map)
          ref_up ||= Geom::Vector3d.new(0, 0, 1)
          s       = ref_up.dot(scale_axis_world)
          up_perp = Geom::Vector3d.new(
            ref_up.x - scale_axis_world.x * s,
            ref_up.y - scale_axis_world.y * s,
            ref_up.z - scale_axis_world.z * s
          )
          # Step 3 — shift in the cross-section plane so the "base" face (lowest in
          # the up_perp direction) lands at midpoint. Skipped for vertical edges where
          # up_perp degenerates to zero (cross-section has no defined "down").
          move_base_to_surface(entity_copy, midpoint, up_perp) if up_perp.length > 1e-6
        else
          OrienterExpress.send(:move_insertion_to, entity_copy, midpoint, @insertion_point, @scale_axis)
        end
        @previous_entities << entity_copy
        @placement_map[entity_copy] = edge
      end
    end

    def self.oezscale
      model   = Sketchup.active_model
      edges   = (edges(model.selection) + faces(model.selection).flat_map(&:edges)).uniq
      targets = instances(model.selection)

      rotation_mode = CONFIG[:rotation_mode].to_sym rescue :ground
      rotation_mode = :ground unless %i[ground flow normal].include?(rotation_mode)
      flow_map = {}
      if rotation_mode == :flow
        vertex_edges = {}
        edges.each do |edge|
          [edge.start, edge.end].each do |v|
            vertex_edges[v] ||= []
            vertex_edges[v] << edge
          end
        end
        flow_map = all_vertex_flow_directions(vertex_edges)
      end

      entity = targets.first
      model.select_tool(
        OEZScaleTool.new(edges, entity, flow_map, rotation_mode)
      )
    end

    class OEUScaleTool < OEPlacementTool

      def self.cursor_id(variant = :default)
        @@cursor_ids ||= {}
        @@cursor_ids[variant] ||= begin
          ext      = Sketchup.platform == :platform_win ? 'svg' : 'pdf'
          filename = variant == :default ? "oe_uscale_32" : "oe_uscale_#{variant}_32"
          UI.create_cursor(File.join(PATH_CURSORS, "#{filename}.#{ext}"), 5, 5)
        end
      end

      # No persistent offset — always zero, setter is a no-op
      def self.last_offset_str
        Sketchup.format_length(0)
      end

      def self.last_offset_str=(_val); end

      def initialize(edges, entity, flow_map, rotation_mode)
        super(edges, entity)
        @flow_map        = flow_map
        @rotation_mode   = rotation_mode
        @scale_axis      = :z
        ip = OrienterExpress.send(:resolved_insertion_point, :oeuscale).to_sym
        @insertion_point = %i[center base].include?(ip) ? ip : :center
      end

      private

      def scroll_offset(_dir); end  # no offset concept for uniform scale

      def on_drag(ctrl, shift, view, x, y)
        return unless @lbutton_down && @drag_mode && ctrl
        entity = pick_entity(view, x, y, 16)
        entity = @placement_map[entity] if entity && @placement_map.key?(entity)
        picked = pick_geometry_from_entity(entity)
        modify_geometry(@drag_mode, picked) if picked
      end

      def on_geometry_changed
        rebuild_flow_map if @rotation_mode == :flow
      end

      def on_selection_changed(new_set, old_set)
        if @rotation_mode == :flow
          rebuild_flow_map
          apply(nil)
        else
          apply_diff((new_set - old_set).to_a, (old_set - new_set).to_a)
        end
      end

      def sync_selection
        valid_edges = @geometry.select(&:valid?)
        edge_set    = valid_edges.to_set
        full_faces  = valid_edges.flat_map(&:faces).uniq.select { |f|
          f.valid? && f.edges.all? { |e| edge_set.include?(e) }
        }
        source    = (@source_entity && @source_entity.valid?) ? [@source_entity] : []
        target    = (valid_edges + full_faces + source).to_set
        current   = @model.selection.to_a.to_set
        to_remove = (current - target).to_a
        to_add    = (target - current).to_a
        @model.selection.remove(to_remove) unless to_remove.empty?
        @model.selection.add(to_add)       unless to_add.empty?
      end

      def cancel_op_name
        "Cancel Uniform Scaling"
      end

      def handle_mode_key
        @rotation_mode = @rotation_mode == :flow ? :ground : :flow
        rebuild_flow_map if @rotation_mode == :flow
        update_vcb
        apply(nil)
      end

      def handle_key(_key); end

      def handle_ins_key
        @insertion_point = @insertion_point == :center ? :base : :center
        custom = CONFIG[:insertion_point_custom].dup
        custom[:oeuscale] = @insertion_point.to_s
        OrienterExpress.user_settings(insertion_point_custom: custom)
        update_vcb
        apply(nil)
      end

      def debug_tool_name;        "oeuscale"; end
      def valid_insertion_points; %i[center base]; end
      def no_sample_hint;   Lang.commands.oeuscale.no_sample_hint.to_s;   end
      def no_geometry_hint; Lang.commands.oeuscale.no_geometry_hint.to_s; end

      def render_vcb
        mode_key   = @rotation_mode == :flow ? :rotation_flow : :rotation_ground
        mode_label = Lang.t(:html, :settings, mode_key)
        ip_key     = @insertion_point == :base ? :insertion_base_short : :insertion_center_short
        ip_label   = Lang.t(:html, :settings, ip_key)
        hint = format(Lang.commands.oeuscale.vcb_hint.to_s, mode: mode_label, roll: roll_label)
        Sketchup.set_status_text("", 1)
        Sketchup.set_status_text("", 2)
        Sketchup.set_status_text(build_status(hint), 0)
        debug_state
      end

      def apply(_text)
        return unless @entity_def
        transparent = !@first_apply
        @model.start_operation("Orienter Express: Uniform Scaling", true, false, transparent)
        begin
          @previous_entities.each { |e| e.erase! if e.valid? }
          @previous_entities = []
          @placement_map     = {}
          @geometry.each { |edge| place_for_edge(edge) }
          @model.commit_operation
          @first_apply = false
          @applied     = true
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

      def apply_diff(added, removed)
        return unless @entity_def
        @model.start_operation("Orienter Express: Uniform Scaling", true, false, true)
        begin
          removed.each do |edge|
            to_erase = @placement_map.select { |_, e| e == edge }.keys
            to_erase.each { |ent| ent.erase! if ent.valid? }
            to_erase.each { |ent| @previous_entities.delete(ent); @placement_map.delete(ent) }
          end
          added.each { |edge| place_for_edge(edge) }
          @model.commit_operation
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

      def place_for_edge(edge)
        return if edge.length.zero?
        entity_copy = OrienterExpress.create_entity_copy(@entity_def, @entity_t)
        OrienterExpress.uniform_scale(entity_copy, edge)
        OrienterExpress.orient_z(entity_copy, edge)
        if @rotation_mode == :flow
          OrienterExpress.send(:orient_to_flow, entity_copy, edge, @flow_map)
        else
          OrienterExpress.orient_x(entity_copy)
        end
        midpoint = Geom::Point3d.linear_combination(0.5, edge.start.position, 0.5, edge.end.position)
        apply_roll(entity_copy)
        edge_normal = avg_face_normal_for_edge(edge)
        place_with_insertion(entity_copy, midpoint, edge_normal, edge)
        @previous_entities << entity_copy
        @placement_map[entity_copy] = edge
      end

    end

    def self.oeuscale
      model  = Sketchup.active_model
      edges  = (edges(model.selection) + faces(model.selection).flat_map(&:edges)).uniq
      entity = instances(model.selection).first

      rotation_mode = CONFIG[:rotation_mode].to_sym rescue :ground
      rotation_mode = :ground unless %i[ground flow].include?(rotation_mode)
      flow_map = {}
      if rotation_mode == :flow
        vertex_edges = {}
        edges.each do |edge|
          [edge.start, edge.end].each do |v|
            vertex_edges[v] ||= []
            vertex_edges[v] << edge
          end
        end
        flow_map = all_vertex_flow_directions(vertex_edges)
      end

      model.select_tool(OEUScaleTool.new(edges, entity, flow_map, rotation_mode))
    end

    # Tool class for interactive Flow Placement.
    # Places components at edge vertices aligned to the flow direction.
    # The user adjusts an offset along the flow direction via the VCB or arrow keys.
    class OEFlowTool < OEPlacementTool

      def self.last_offset_str
        @@last_offset_str ||= OrienterExpress.send(:load_offset_str, :oeflow_offset)
      end

      def self.last_offset_str=(val)
        @@last_offset_str = val
      end

      def self.cursor_id(variant = :default)
        @@cursor_ids ||= {}
        @@cursor_ids[variant] ||= begin
          ext      = Sketchup.platform == :platform_win ? 'svg' : 'pdf'
          filename = variant == :default ? "oeflow_32" : "oeflow_#{variant}_32"
          path     = File.join(PATH_CURSORS, "#{filename}.#{ext}")
          UI.create_cursor(path, 5, 5)
        end
      end

      def initialize(edges, entity, flow_map, rotation_mode)
        super(edges, entity)
        @flow_map        = flow_map
        @rotation_mode   = rotation_mode
        @scale_axis      = :z
        @insertion_point = OrienterExpress.send(:resolved_insertion_point, :oeflow).to_sym
      end

      private

      def on_drag(ctrl, shift, view, x, y)
        return unless @lbutton_down && @drag_mode && ctrl
        entity = pick_entity(view, x, y)
        picked = pick_geometry_from_entity(entity)
        modify_geometry(@drag_mode, picked) if picked
      end

      # OEFlow always does a full re-apply on external selection change
      def on_selection_changed(_new_set, _old_set)
        apply(OEFlowTool.last_offset_str)
      end

      # OEFlow sync_selection does not include full_faces
      def sync_selection
        source    = (@source_entity && @source_entity.valid?) ? [@source_entity] : []
        target    = (@geometry.select(&:valid?) + source).to_set
        current   = @model.selection.to_a.to_set
        to_remove = (current - target).to_a
        to_add    = (target - current).to_a
        @model.selection.remove(to_remove) unless to_remove.empty?
        @model.selection.add(to_add)       unless to_add.empty?
      end

      def cancel_op_name
        "Cancel Flow Placement"
      end

      def handle_key(key)
        case key
        when 9 # Tab — cycle axis
          handle_axis_key
        end
      end

      def handle_axis_key
        @scale_axis  = { z: :x, x: :y, y: :z }[@scale_axis]
        @first_apply = true
        update_vcb
        apply(OEFlowTool.last_offset_str)
      end

      def handle_ins_key
        @insertion_point = { center: :base, base: :origin, origin: :center }[@insertion_point]
        custom = CONFIG[:insertion_point_custom].dup
        custom[:oeflow] = @insertion_point.to_s
        OrienterExpress.user_settings(insertion_point_custom: custom)
        update_vcb
        apply(OEFlowTool.last_offset_str)
      end

      def handle_mode_key
        @rotation_mode = { ground: :flow, flow: :normal, normal: :ground }[@rotation_mode]
        update_vcb
        apply(OEFlowTool.last_offset_str)
      end

      def debug_tool_name;  "oeflow"; end
      def no_sample_hint;   Lang.commands.oeflow.no_sample_hint.to_s;   end
      def no_geometry_hint; Lang.commands.oeflow.no_geometry_hint.to_s; end

      def render_vcb
        mode_key   = { ground: :rotation_ground, flow: :rotation_flow, normal: :rotation_normal }[@rotation_mode]
        mode_label = Lang.t(:html, :settings, mode_key)
        axis_label = @scale_axis.to_s.upcase
        ip_key     = { base: :insertion_base_short, center: :insertion_center_short, origin: :insertion_origin_short }[@insertion_point]
        ip_label   = Lang.t(:html, :settings, ip_key)
        hint = format(Lang.commands.oeflow.vcb_hint.to_s, mode: mode_label, axis: axis_label, ip: ip_label, roll: roll_label, offset: OEFlowTool.last_offset_str)
        Sketchup.set_status_text(Lang.commands.oeflow.offset_prompt.to_s, 1)
        Sketchup.set_status_text(OEFlowTool.last_offset_str, 2)
        Sketchup.set_status_text(build_status(hint), 0)
        debug_state
      end

      def apply(text)
        return unless @entity_def
        offset = OrienterExpress.send(:parse_length_safe, text)
        return unless offset

        vertex_edges = {}
        @geometry.select(&:valid?).each do |edge|
          [edge.start, edge.end].each do |v|
            vertex_edges[v] ||= []
            vertex_edges[v] << edge
          end
        end
        flow_map  = OrienterExpress.send(:all_vertex_flow_directions, vertex_edges)
        @flow_map = flow_map

        transparent = !@first_apply
        @model.start_operation("Orienter Express: Flow Placement", true, false, transparent)

        begin
          @previous_entities.each { |e| e.erase! if e.valid? }
          @previous_entities = []
          @placement_map     = {}

          flow_map.each do |vertex, direction|
            target      = vertex.position.offset(direction.normalize, offset)
            entity_copy = OrienterExpress.create_entity_copy(@entity_def, @entity_t)
            t           = entity_copy.transformation

            # Align primary axis to flow direction
            case @scale_axis
            when :x
              OrienterExpress.send(:align_axis, entity_copy, t.origin, t.xaxis, direction)
            when :y
              OrienterExpress.send(:align_axis, entity_copy, t.origin, t.yaxis, direction)
            else
              OrienterExpress.send(:align_axis, entity_copy, t.origin, t.zaxis, direction)
            end

            # Representative edge for rotation modes that need an edge reference
            rep_edge = vertex_edges[vertex] ? vertex_edges[vertex].first : nil

            # Secondary orientation (rotation mode)
            case @rotation_mode
            when :flow
              if rep_edge
                case @scale_axis
                when :x
                  OrienterExpress.send(:orient_to_flow_around, entity_copy, rep_edge, flow_map,
                                       entity_copy.transformation.xaxis,
                                       entity_copy.transformation.zaxis)
                when :y
                  OrienterExpress.send(:orient_to_flow_around, entity_copy, rep_edge, flow_map,
                                       entity_copy.transformation.yaxis,
                                       entity_copy.transformation.zaxis)
                else
                  OrienterExpress.send(:orient_to_flow, entity_copy, rep_edge, flow_map)
                end
              else
                OrienterExpress.orient_x(entity_copy)
              end
            when :normal
              if rep_edge
                case @scale_axis
                when :x
                  OrienterExpress.send(:orient_to_face_normal_around, entity_copy, rep_edge,
                                       entity_copy.transformation.xaxis,
                                       entity_copy.transformation.zaxis)
                when :y
                  OrienterExpress.send(:orient_to_face_normal_around, entity_copy, rep_edge,
                                       entity_copy.transformation.yaxis,
                                       entity_copy.transformation.zaxis)
                else
                  OrienterExpress.send(:orient_to_face_normal, entity_copy, rep_edge, @h_dir_map)
                end
              else
                OrienterExpress.orient_x(entity_copy)
              end
            else # ground
              case @scale_axis
              when :x
                OrienterExpress.send(:orient_ground_around, entity_copy,
                                     entity_copy.transformation.xaxis,
                                     entity_copy.transformation.yaxis)
              when :y
                OrienterExpress.send(:orient_ground_around, entity_copy,
                                     entity_copy.transformation.yaxis,
                                     entity_copy.transformation.zaxis)
              else
                OrienterExpress.send(:orient_x_ground, entity_copy, rep_edge, @h_dir_map)
              end
            end

            apply_roll(entity_copy)
            flow_normal = rep_edge ? avg_face_normal_for_edge(rep_edge) : nil
            place_with_insertion(entity_copy, target, flow_normal, rep_edge)
            @previous_entities << entity_copy
            @placement_map[entity_copy] = vertex
          end

          @model.commit_operation
          @first_apply = false
          @applied     = true
          formatted = OrienterExpress.send(:format_and_persist_offset, offset, :oeflow_offset)
          OEFlowTool.last_offset_str = formatted
          Sketchup.set_status_text(formatted, 2)
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end
    end

    def self.oeflow
      model   = Sketchup.active_model
      edges   = (edges(model.selection) + faces(model.selection).flat_map(&:edges)).uniq
      targets = instances(model.selection)

      rotation_mode = CONFIG[:rotation_mode].to_sym rescue :ground
      rotation_mode = :ground unless %i[ground flow normal].include?(rotation_mode)
      flow_map = {}
      if rotation_mode == :flow
        vertex_edges = {}
        edges.each do |edge|
          [edge.start, edge.end].each do |v|
            vertex_edges[v] ||= []
            vertex_edges[v] << edge
          end
        end
        flow_map = all_vertex_flow_directions(vertex_edges)
      end

      entity = targets.first
      model.select_tool(
        OEFlowTool.new(edges, entity, flow_map, rotation_mode)
      )
    end

    # Tool class for interactive Surface Placement.
    # Places one component instance per smooth-connected face group, using the
    # area-weighted average normal and a ray-projected contact point so that
    # placement lands on the surface rather than inside curved geometry.
    class OESurfaceTool < OEPlacementTool

      def self.last_offset_str
        @@last_offset_str ||= OrienterExpress.send(:load_offset_str, :oesurface_offset)
      end

      def self.last_offset_str=(val)
        @@last_offset_str = val
      end

      def self.cursor_id(variant = :default)
        @@cursor_ids ||= {}
        @@cursor_ids[variant] ||= begin
          ext      = Sketchup.platform == :platform_win ? 'svg' : 'pdf'
          filename = variant == :default ? "oesurface_32" : "oesurface_#{variant}_32"
          path     = File.join(PATH_CURSORS, "#{filename}.#{ext}")
          UI.create_cursor(path, 5, 5)
        end
      end

      def initialize(faces, entity)
        super(faces, entity)
        @insertion_point = OrienterExpress.send(:resolved_insertion_point, :oesurface).to_sym
        @scale_axis      = :z
        @axis_idx        = 0
        @smooth_groups   = CONFIG[:smooth_groups] != false
      end

      def on_config_changed(changed)
        super
        if changed.key?(:smooth_groups)
          new_val = changed[:smooth_groups] != false
          return if new_val == @smooth_groups
          @smooth_groups = new_val
          @first_apply   = true
          apply(OESurfaceTool.last_offset_str)
        end
      end

      private

      # Flood-fill via softened/smoothed edges only.
      def soft_group_for(face)
        visited = {}
        queue   = [face]
        until queue.empty?
          f = queue.pop
          next if visited[f]
          visited[f] = true
          f.edges.each do |e|
            next unless e.soft? || e.smooth?
            e.faces.each { |n| queue << n unless visited[n] }
          end
        end
        visited.keys
      end

      # Single click expands the picked face/edge to its full soft group.
      def pick_geometry_from_entity(entity)
        case entity
        when Sketchup::Face
          soft_group_for(entity)
        when Sketchup::Edge
          entity.faces.flat_map { |f| soft_group_for(f) }.uniq
        end
      end

      # Double-click flood-fill via all edges (selects all connected geometry).
      def connected_geometry(entity)
        start_faces = pick_geometry_from_entity(entity)
        return nil unless start_faces
        visited = {}
        queue   = start_faces.dup
        until queue.empty?
          face = queue.pop
          next if visited[face]
          visited[face] = true
          face.edges.each do |e|
            e.faces.each { |f| queue << f unless visited[f] }
          end
        end
        visited.keys
      end

      def handle_geometry_click(ctrl, shift, view, x, y, click_type)
        ph = view.pick_helper
        ph.do_pick(x, y)
        raw  = ph.best_picked
        best = @placement_map.key?(raw) ? @placement_map[raw] : raw

        picked = case click_type
                 when :single then pick_geometry_from_entity(best)
                 when :double then connected_geometry(best)
                 end

        mode = if ctrl && shift
                 :remove
               elsif ctrl
                 :add
               else
                 :replace
               end

        @drag_mode = mode unless mode == :replace
        return unless picked
        modify_geometry(mode, picked)
      end

      def on_drag(ctrl, shift, view, x, y)
        return unless @lbutton_down && @drag_mode && ctrl
        ph = view.pick_helper
        ph.do_pick(x, y)
        picked = pick_geometry_from_entity(ph.best_picked)
        modify_geometry(@drag_mode, picked) if picked
      end

      def collect_geometry_from_selection(selection)
        (selection.grep(Sketchup::Face) +
         selection.grep(Sketchup::Edge).flat_map(&:faces)).uniq.select(&:valid?)
      end

      # External selection changes trigger a full re-apply because group
      # boundaries depend on the full set of selected faces.
      def on_selection_changed(_new_set, _old_set)
        apply(OESurfaceTool.last_offset_str)
      end

      def sync_selection
        source    = (@source_entity && @source_entity.valid?) ? [@source_entity] : []
        target    = (@geometry.select(&:valid?) + source).to_set
        current   = @model.selection.to_a.to_set
        to_remove = (current - target).to_a
        to_add    = (target - current).to_a
        @model.selection.remove(to_remove) unless to_remove.empty?
        @model.selection.add(to_add)       unless to_add.empty?
      end

      def cancel_op_name
        "Cancel Surface Placement"
      end

      def rebuild_h_dir_map; end

      def handle_key(key)
        case key
        when 9 # Tab — cycle axis
          handle_axis_key
        end
      end

      def handle_axis_key
        @scale_axis  = { z: :x, x: :y, y: :z }[@scale_axis]
        @first_apply = true
        update_vcb
        apply(OESurfaceTool.last_offset_str)
      end

      def handle_ins_key
        @insertion_point = { center: :base, base: :origin, origin: :center }[@insertion_point]
        custom = CONFIG[:insertion_point_custom].dup
        custom[:oesurface] = @insertion_point.to_s
        OrienterExpress.user_settings(insertion_point_custom: custom)
        update_vcb
        apply(OESurfaceTool.last_offset_str)
      end

      def handle_mode_key
        @axis_idx = (@axis_idx + 1) % 3
        update_vcb
        apply(OESurfaceTool.last_offset_str)
      end

      def debug_tool_name;  "oesurface"; end
      def no_sample_hint;   Lang.commands.oesurface.no_sample_hint.to_s;   end
      def no_geometry_hint; Lang.commands.oesurface.no_geometry_hint.to_s; end

      def render_vcb
        scale_label  = @scale_axis.to_s.upcase
        orient_label = [
          Lang.commands.oesurface.axis_parallel,
          Lang.commands.oesurface.axis_perp,
          Lang.commands.oesurface.axis_ground
        ][@axis_idx]
        ip_key   = { base: :insertion_base_short, center: :insertion_center_short, origin: :insertion_origin_short }[@insertion_point]
        ip_label = Lang.t(:html, :settings, ip_key)
        hint = format(Lang.commands.oesurface.vcb_hint.to_s, axis: scale_label, orient: orient_label, ip: ip_label, roll: roll_label, offset: OESurfaceTool.last_offset_str)
        Sketchup.set_status_text(Lang.commands.oesurface.offset_prompt.to_s, 1)
        Sketchup.set_status_text(OESurfaceTool.last_offset_str, 2)
        Sketchup.set_status_text(build_status(hint), 0)
        debug_state
      end

      # No incremental diff — always do a full re-apply.
      def apply_diff(_added, _removed, _offset)
        apply(OESurfaceTool.last_offset_str)
      end

      def apply(text)
        return unless @entity_def
        offset = OrienterExpress.send(:parse_length_safe, text)
        return unless offset

        transparent = !@first_apply
        @model.start_operation("Orienter Express: Surface Placement", true, false, transparent)

        begin
          @previous_entities.each { |e| e.erase! if e.valid? }
          @previous_entities = []
          @placement_map     = {}

          if @smooth_groups
            compute_groups.each { |group| place_for_group(group, offset) }
          else
            @geometry.select(&:valid?).each { |face| place_for_group([face], offset) }
          end

          @model.commit_operation
          @first_apply = false
          @applied     = true
          formatted = OrienterExpress.send(:format_and_persist_offset, offset, :oesurface_offset)
          OESurfaceTool.last_offset_str = formatted
          Sketchup.set_status_text(formatted, 2)
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

      # Partition @geometry into non-overlapping soft groups.
      def compute_groups
        geo_set  = @geometry.to_set
        assigned = {}
        groups   = []
        @geometry.each do |face|
          next if assigned[face] || !face.valid?
          group = soft_group_for(face).select { |f| geo_set.include?(f) && f.valid? }
          next if group.empty?
          groups << group
          group.each { |f| assigned[f] = true }
        end
        groups
      end

      # Place one entity copy for a smooth group using the area-weighted
      # average normal and centroid of the group's faces.
      # Returns silently if the geometry is degenerate (e.g. zero-length
      # average normal on a full cylinder where normals cancel out).
      def place_for_group(group_faces, offset)
        valid = group_faces.select(&:valid?)
        return if valid.empty?

        total_area = 0.0
        nx = 0.0; ny = 0.0; nz = 0.0
        cx = 0.0; cy = 0.0; cz = 0.0

        valid.each do |face|
          area     = face.area
          normal   = face.normal
          centroid = OrienterExpress.send(:face_centroid, face)
          total_area += area
          nx += normal.x * area; ny += normal.y * area; nz += normal.z * area
          cx += centroid.x * area; cy += centroid.y * area; cz += centroid.z * area
        end

        return if total_area < 1e-6
        avg_normal = Geom::Vector3d.new(nx / total_area, ny / total_area, nz / total_area)
        return if avg_normal.length < 1e-6

        # Area-weighted centroid — correct for flat groups, but may fall
        # inside the geometry for curved surfaces (e.g. a cylinder segment).
        avg_centroid = Geom::Point3d.new(cx / total_area, cy / total_area, cz / total_area)

        # Surface contact point: project avg_centroid onto the surface along
        # avg_normal. For each face we solve where the ray
        #   avg_centroid + t * avg_normal
        # crosses the face plane; the crossing with the smallest |t| is the
        # surface point closest to avg_centroid along the normal direction.
        # For flat groups t ≈ 0 so contact ≈ avg_centroid.
        n = avg_normal.normalize
        contact   = avg_centroid
        min_abs_t = Float::INFINITY

        valid.each do |face|
          denom = face.normal.dot(n)
          next if denom.abs < 1e-6   # face plane parallel to avg_normal

          fc    = OrienterExpress.send(:face_centroid, face)
          ray_t = face.normal.dot(fc - avg_centroid) / denom
          next unless ray_t.abs < min_abs_t

          min_abs_t = ray_t.abs
          contact   = avg_centroid.offset(n, ray_t)
        end

        target = contact.offset(n, offset)

        entity_copy = OrienterExpress.create_entity_copy(@entity_def, @entity_t)
        t           = entity_copy.transformation

        case @scale_axis
        when :x then OrienterExpress.align_axis(entity_copy, t.origin, t.xaxis, avg_normal)
        when :y then OrienterExpress.align_axis(entity_copy, t.origin, t.yaxis, avg_normal)
        else         OrienterExpress.align_axis(entity_copy, t.origin, t.zaxis, avg_normal)
        end

        # Use the largest face in the group for edge-based orientation
        primary = valid.max_by(&:area)
        if @axis_idx == 2
          OrienterExpress.orient_x(entity_copy)
        else
          OrienterExpress.orient_to_face_edge(entity_copy, primary, @axis_idx, @scale_axis)
        end

        apply_roll(entity_copy)
        base_axis = @insertion_point == :base ? axis_most_aligned_to(entity_copy, avg_normal) : @scale_axis
        OrienterExpress.send(:move_insertion_to, entity_copy, target, @insertion_point, base_axis)

        @previous_entities << entity_copy
        @placement_map[entity_copy] = primary
      rescue
        # Degenerate geometry (zero-length vector, cancelled normals, etc.)
        # — skip this group silently so the rest of the placement continues.
      end

    end

    def self.oesurface
      model   = Sketchup.active_model
      faces   = (faces(model.selection) + edges(model.selection).flat_map(&:faces)).uniq
      targets = instances(model.selection)

      entity = targets.first
      model.select_tool(
        OESurfaceTool.new(faces, entity)
      )
    end

    ### EXTRA TOOLS ### -----------------------------------------------------------

    # Tool class for interactive Reset Rotations.
    # Tab cycles the pivot point; the reset is re-applied live on each change.
    class OEResetTool

      BB_EDGES = [[0,1],[0,2],[1,3],[2,3],[4,5],[4,6],[5,7],[6,7],[0,4],[1,5],[2,6],[3,7]].freeze

      def self.cursor_id
        @@cursor_id ||= begin
          ext  = Sketchup.platform == :platform_win ? 'svg' : 'pdf'
          path = File.join(PATH_CURSORS, "oe_reset_32.#{ext}")
          UI.create_cursor(path, 5, 5)
        end
      end

      def initialize(targets)
        @model           = Sketchup.active_model
        @hovered         = nil
        custom = CONFIG[:insertion_point_custom]
        @insertion_point = (custom.is_a?(Hash) && custom[:oereset] ? custom[:oereset].to_sym : :base)
        # Apply immediately to any pre-selected targets
        @pending_targets = targets
      end

      def activate
        @model.selection.clear unless @model.selection.empty?
        update_vcb
        UI.start_timer(0, false) { apply_to(@pending_targets) unless @pending_targets.empty? }
      end

      def deactivate(view)
        @hovered = nil
        view.invalidate
      end

      def resume(_view)
        update_vcb
      end

      def suspend(view)
        @hovered = nil
        view.invalidate
      end

      def enableVCB?
        false
      end

      def onMouseMove(_flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        entity    = ph.best_picked
        candidate = (entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)) ? entity : nil
        if candidate != @hovered
          @hovered = candidate
          view.invalidate
        end
      end

      def draw(view)
        return unless @hovered && @hovered.valid?
        t       = @hovered.transformation
        def_bb  = @hovered.definition.bounds
        corners = 8.times.map { |i| t * def_bb.corner(i) }
        eye     = view.camera.eye
        view.line_width    = 2
        view.drawing_color = Sketchup::Color.new(148, 0, 211)
        BB_EDGES.each do |a, b|
          pa = corners[a].offset((eye - corners[a]).normalize, 0.1)
          pb = corners[b].offset((eye - corners[b]).normalize, 0.1)
          view.draw(GL_LINES, [pa, pb])
        end
      end

      def getExtents
        bb = Geom::BoundingBox.new
        if @hovered && @hovered.valid?
          t = @hovered.transformation
          8.times { |i| bb.add(t * @hovered.definition.bounds.corner(i)) }
        end
        bb
      end

      def onSetCursor
        UI.set_cursor(OEResetTool.cursor_id)
      end

      def onLButtonDown(_flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        entity = ph.best_picked
        return unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
        apply_to([entity])
      end

      def onKeyDown(key, _repeat, _flags, _view)
        case key
        when 27 # Esc — exit
          @model.select_tool(nil)
        when 9 # Tab — cycle pivot
          @insertion_point = { center: :origin, origin: :base, base: :center }[@insertion_point]
          custom = CONFIG[:insertion_point_custom] || {}
          OrienterExpress.user_settings(insertion_point_custom: custom.merge(oereset: @insertion_point.to_s))
          update_vcb
        end
      end

      private

      def pivot_for(entity, original_t)
        case @insertion_point
        when :origin
          original_t.origin
        when :base
          db = entity.definition.bounds
          original_t * Geom::Point3d.new(db.center.x, db.center.y, db.min.z)
        else # :center
          (original_t * entity.definition.bounds.center)
        end
      end

      def update_vcb
        ip_key = { base: :insertion_base_short, center: :insertion_center_short, origin: :insertion_origin_short }[@insertion_point]
        ip = Lang.t(:html, :settings, ip_key)
        Sketchup.set_status_text("#{Lang.commands.oereset.vcb_hint}  |  #{ip}", 0)
      end

      def apply_to(targets)
        return if targets.empty?
        @model.start_operation("Orienter Express: Reset Rotations", true)
        begin
          targets.each do |entity|
            next unless entity.valid?
            original_t = entity.transformation
            pivot      = pivot_for(entity, original_t)
            OrienterExpress.send(:align_axis, entity, pivot, entity.transformation.zaxis, Z_AXIS)
            OrienterExpress.send(:align_axis, entity, pivot, entity.transformation.xaxis, X_AXIS)
          end
          @model.commit_operation
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end
    end

    def self.oereset
      model   = Sketchup.active_model
      targets = instances(model.selection)
      model.select_tool(OEResetTool.new(targets))
    end

    # Recursively collects all vertex positions transformed by t.
    def self.collect_vertices(entities, t)
      pts = []
      entities.each do |e|
        case e
        when Sketchup::Edge
          pts << t * e.start.position
          pts << t * e.end.position
        when Sketchup::ComponentInstance, Sketchup::Group
          pts.concat(collect_vertices(e.definition.entities, t * e.transformation))
        end
      end
      pts
    end

    # 2D convex hull via Andrew's monotone chain. pts is Array<[x, y]>.
    # Returns CCW-ordered hull vertices (same [x, y] tuples).
    def self.convex_hull_2d(pts)
      return pts.dup if pts.size < 3
      sorted = pts.sort_by { |p| [p[0], p[1]] }.uniq
      return sorted if sorted.size < 3

      cross = lambda do |o, a, b|
        (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
      end

      lower = []
      sorted.each do |p|
        lower.pop while lower.size >= 2 && cross.call(lower[-2], lower[-1], p) <= 0
        lower << p
      end

      upper = []
      sorted.reverse_each do |p|
        upper.pop while upper.size >= 2 && cross.call(upper[-2], upper[-1], p) <= 0
        upper << p
      end

      lower[0..-2] + upper[0..-2]
    end

    # Returns the subset of pts that form the 3D convex hull (QuickHull algorithm).
    # Guarantees no extreme point is lost, which is required for exact BB computation.
    def self.convex_hull_3d(pts)
      convex_hull_3d_with_faces(pts).first
    end

    # Same QuickHull, but also returns outward-oriented triangular faces.
    # Returns [hull_pts, face_triples] where face_triples indexes into hull_pts.
    def self.convex_hull_3d_with_faces(pts)
      return [pts, []] if pts.size <= 3

      eps = 1e-8

      # Signed distance from the plane of face [ia,ib,ic] to point p.
      # Positive = p is on the outside (outward normal side).
      sd = lambda do |ia, ib, ic, p|
        a=pts[ia]; b=pts[ib]; c=pts[ic]
        ux=b.x-a.x; uy=b.y-a.y; uz=b.z-a.z
        vx=c.x-a.x; vy=c.y-a.y; vz=c.z-a.z
        nx=uy*vz-uz*vy; ny=uz*vx-ux*vz; nz=ux*vy-uy*vx
        nx*(p.x-a.x) + ny*(p.y-a.y) + nz*(p.z-a.z)
      end

      # Extreme point indices (min/max in each axis)
      ext = [:x,:y,:z].flat_map { |ax|
        [pts.each_with_index.min_by{|p,_| p.send(ax)}[1],
         pts.each_with_index.max_by{|p,_| p.send(ax)}[1]]
      }.uniq

      # Initial tetrahedron: most distant pair, then farthest from line, farthest from plane
      i0, i1 = ext.combination(2).max_by { |a,b|
        pa=pts[a]; pb=pts[b]; (pa.x-pb.x)**2+(pa.y-pb.y)**2+(pa.z-pb.z)**2
      }
      la=pts[i0]; lb=pts[i1]; ddx=lb.x-la.x; ddy=lb.y-la.y; ddz=lb.z-la.z
      i2 = (0...pts.size).reject{|i|i==i0||i==i1}.max_by { |i|
        p=pts[i]; ex=p.x-la.x; ey=p.y-la.y; ez=p.z-la.z
        cx=ddy*ez-ddz*ey; cy=ddz*ex-ddx*ez; cz=ddx*ey-ddy*ex; cx*cx+cy*cy+cz*cz
      }
      return [pts, []] unless i2
      i3 = (0...pts.size).reject{|i|[i0,i1,i2].include?(i)}.max_by { |i|
        sd.call(i0,i1,i2, pts[i]).abs
      }
      return [pts, []] if i3.nil? || sd.call(i0,i1,i2, pts[i3]).abs < eps

      # Interior reference: centroid of tetrahedron (always inside the final hull)
      ctr = Geom::Point3d.new(
        (pts[i0].x+pts[i1].x+pts[i2].x+pts[i3].x)/4.0,
        (pts[i0].y+pts[i1].y+pts[i2].y+pts[i3].y)/4.0,
        (pts[i0].z+pts[i1].z+pts[i2].z+pts[i3].z)/4.0)

      # Orient face [a,b,c] so that ctr is on the inside (negative side)
      orient = lambda do |a, b, c|
        aa=pts[a]; bb=pts[b]; cc=pts[c]
        ux=bb.x-aa.x; uy=bb.y-aa.y; uz=bb.z-aa.z
        vx=cc.x-aa.x; vy=cc.y-aa.y; vz=cc.z-aa.z
        nx=uy*vz-uz*vy; ny=uz*vx-ux*vz; nz=ux*vy-uy*vx
        (nx*(ctr.x-aa.x)+ny*(ctr.y-aa.y)+nz*(ctr.z-aa.z)) < 0 ? [a,b,c] : [a,c,b]
      end

      faces   = [orient.call(i0,i1,i2), orient.call(i0,i1,i3),
                 orient.call(i0,i2,i3), orient.call(i1,i2,i3)]
      seed    = [i0,i1,i2,i3].to_set
      outside = Array.new(4) { [] }
      (0...pts.size).each do |i|
        next if seed.include?(i)
        4.times { |fi| (outside[fi] << i; break) if sd.call(*faces[fi], pts[i]) > eps }
      end

      loop do
        fi = outside.index { |s| s && !s.empty? }
        break unless fi

        apex    = outside[fi].max_by { |i| sd.call(*faces[fi], pts[i]) }
        visible = (0...faces.size).select { |i| faces[i] && sd.call(*faces[i], pts[apex]) > eps }

        # Horizon: edges [a,b] in visible faces whose reverse [b,a] is not in a visible face
        vis_edges = {}
        visible.each { |vi| f=faces[vi]; [[f[0],f[1]],[f[1],f[2]],[f[2],f[0]]].each{|e| vis_edges[e]=vi} }
        horizon = vis_edges.keys.reject { |a,b| vis_edges.key?([b,a]) }

        unassigned = visible.flat_map { |vi| outside[vi] }.uniq - [apex]
        visible.each { |vi| faces[vi] = nil; outside[vi] = nil }

        new_slots = []
        horizon.each do |a, b|
          nf   = orient.call(apex, a, b)
          slot = faces.index(nil)
          unless slot; faces << nil; outside << nil; slot = faces.size - 1; end
          faces[slot] = nf; outside[slot] = []; new_slots << slot
        end

        unassigned.each do |i|
          new_slots.each { |s| (outside[s] << i; break) if sd.call(*faces[s], pts[i]) > eps }
        end
      end

      alive     = faces.compact
      hull_idxs = alive.flatten.uniq
      idx_map   = {}
      hull_idxs.each_with_index { |orig, new_i| idx_map[orig] = new_i }
      hull_pts   = hull_idxs.map { |i| pts[i] }
      face_tris  = alive.map { |f| [idx_map[f[0]], idx_map[f[1]], idx_map[f[2]]] }
      [hull_pts, face_tris]
    end

    # O'Rourke face-flush heuristic for 3D min-volume bounding box.
    # For every convex-hull face, rotates the outward normal to +Z and solves
    # the 2D min-area rectangle in XY via rotating calipers (edge-flush case).
    # Volume = area · z_extent. Returns [r00..r22, vol] in row-major, or nil.
    # At the min-volume optimum at least one BB face is flush with a hull face,
    # so this set of candidates contains the true optimum.
    def self.face_flush_min_bb(pts, faces)
      return nil if pts.empty? || faces.empty?
      half_pi  = Math::PI / 2.0
      best_vol = Float::INFINITY
      best     = nil

      # Flat float arrays avoid Point3d method dispatch in hot loops.
      n2 = pts.size
      px = Array.new(n2); py = Array.new(n2); pz = Array.new(n2)
      pts.each_with_index { |p, i| px[i] = p.x; py[i] = p.y; pz[i] = p.z }

      # Dedupe near-(anti)parallel normals (|dot| > 0.9999 ≈ angle < ~0.8°).
      dedup_tol = 0.9999
      unique_normals = []
      faces.each do |ia, ib, ic|
        ux = px[ib]-px[ia]; uy = py[ib]-py[ia]; uz = pz[ib]-pz[ia]
        vx = px[ic]-px[ia]; vy = py[ic]-py[ia]; vz = pz[ic]-pz[ia]
        nx = uy*vz - uz*vy
        ny = uz*vx - ux*vz
        nz = ux*vy - uy*vx
        nl = Math.sqrt(nx*nx + ny*ny + nz*nz)
        next if nl < 1e-10
        nx /= nl; ny /= nl; nz /= nl
        next if unique_normals.any? { |mx, my, mz| (nx*mx + ny*my + nz*mz).abs > dedup_tol }
        unique_normals << [nx, ny, nz]
      end
      Debug.log(self, :align_pca, "[face-flush] normals dedup: #{faces.size} → #{unique_normals.size}")

      ptsX = Array.new(n2)
      ptsY = Array.new(n2)

      unique_normals.each do |nx, ny, nz|
        # Rodrigues: rotation that maps normal n → +Z.
        # axis = n × ẑ = (ny, -nx, 0), sin(θ) = |axis|, cos(θ) = n·ẑ = nz
        rax = ny; ray = -nx
        rl  = Math.sqrt(rax*rax + ray*ray)
        if rl < 1e-10
          if nz >= 0
            r11=1.0;r12=0.0;r13=0.0;  r21=0.0;r22=1.0;r23=0.0;  r31=0.0;r32=0.0;r33=1.0
          else
            r11=1.0;r12=0.0;r13=0.0;  r21=0.0;r22=-1.0;r23=0.0; r31=0.0;r32=0.0;r33=-1.0
          end
        else
          kx = rax/rl; ky = ray/rl
          c = nz; s = rl; t = 1.0 - c
          r11 = t*kx*kx + c;    r12 = t*kx*ky;       r13 = s*ky
          r21 = t*kx*ky;        r22 = t*ky*ky + c;   r23 = -s*kx
          r31 = -s*ky;          r32 = s*kx;          r33 = c
        end

        # Rotate hull pts into the frame where the face normal is +Z
        z_min =  Float::INFINITY
        z_max = -Float::INFINITY
        i = 0
        while i < n2
          x = px[i]; y = py[i]; z = pz[i]
          ptsX[i] = r11*x + r12*y + r13*z
          ptsY[i] = r21*x + r22*y + r23*z
          zv      = r31*x + r32*y + r33*z
          z_min = zv if zv < z_min
          z_max = zv if zv > z_max
          i += 1
        end
        z_extent = z_max - z_min
        next if z_extent < 1e-10

        # 2D convex hull via Andrew's monotone chain (lex sort, no atan2)
        order = (0...n2).sort_by { |i| [ptsX[i], ptsY[i]] }
        lo_x = []; lo_y = []
        order.each do |j|
          x = ptsX[j]; y = ptsY[j]
          while lo_x.size >= 2
            ax = lo_x[-2]; ay = lo_y[-2]; bx = lo_x[-1]; by = lo_y[-1]
            break if (bx-ax)*(y-ay) - (by-ay)*(x-ax) > 0
            lo_x.pop; lo_y.pop
          end
          lo_x << x; lo_y << y
        end
        up_x = []; up_y = []
        order.reverse_each do |j|
          x = ptsX[j]; y = ptsY[j]
          while up_x.size >= 2
            ax = up_x[-2]; ay = up_y[-2]; bx = up_x[-1]; by = up_y[-1]
            break if (bx-ax)*(y-ay) - (by-ay)*(x-ax) > 0
            up_x.pop; up_y.pop
          end
          up_x << x; up_y << y
        end
        lo_x.pop; lo_y.pop   # drop duplicated endpoints
        up_x.pop; up_y.pop
        hx = lo_x + up_x
        hy = lo_y + up_y
        next if hx.size < 3

        # Rotating calipers: eval BB area at each edge angle (normalized to [0, π/2))
        nh = hx.size
        edges = nh.times.map { |k|
          j  = (k + 1) % nh
          dx = hx[j] - hx[k]; dy = hy[j] - hy[k]
          (-Math.atan2(dy, dx)) % half_pi
        }.uniq

        # Extremes of a 2D point set coincide with extremes of its convex hull,
        # so calipers only need to iterate the 2D hull (usually << n2).
        edges.each do |theta|
          ct = Math.cos(theta); st = Math.sin(theta)
          u_min =  Float::INFINITY; u_max = -Float::INFINITY
          v_min =  Float::INFINITY; v_max = -Float::INFINITY
          k = 0
          while k < nh
            u = hx[k]*ct - hy[k]*st
            v = hx[k]*st + hy[k]*ct
            u_min = u if u < u_min; u_max = u if u > u_max
            v_min = v if v < v_min; v_max = v if v > v_max
            k += 1
          end
          vol = (u_max - u_min) * (v_max - v_min) * z_extent
          next unless vol < best_vol

          # Compose: Rz(theta) · R_face (row-major, applied to col vectors)
          f11 = ct*r11 - st*r21; f12 = ct*r12 - st*r22; f13 = ct*r13 - st*r23
          f21 = st*r11 + ct*r21; f22 = st*r12 + ct*r22; f23 = st*r13 + ct*r23
          f31 = r31;             f32 = r32;             f33 = r33
          best_vol = vol
          best     = [f11, f12, f13, f21, f22, f23, f31, f32, f33, vol]
        end
      end

      best
    end

    # If the instance transformation contains non-uniform scale, bakes it into
    # the definition geometry so all instances are left with pure rotation.
    # This must run before any alignment so that r_reset extraction and
    # definition-space vertex collection both see unscaled geometry.
    def self.bake_scale(instance)
      t  = instance.transformation
      a  = t.to_a
      sx = Math.sqrt(a[0]**2 + a[1]**2 + a[2]**2)
      sy = Math.sqrt(a[4]**2 + a[5]**2 + a[6]**2)
      sz = Math.sqrt(a[8]**2 + a[9]**2 + a[10]**2)
      return if (sx - sy).abs < 1e-6 && (sx - sz).abs < 1e-6 && (sy - sz).abs < 1e-6

      # Scale transform in definition space. diag(sx,sy,sz) is its own inverse
      # only when uniform; for non-uniform we store the inverse explicitly.
      r_scale     = Geom::Transformation.scaling(sx, sy, sz)
      r_scale_inv = Geom::Transformation.scaling(1.0/sx, 1.0/sy, 1.0/sz)

      instance.definition.entities.transform_entities(r_scale, instance.definition.entities.to_a)
      instance.definition.instances.each do |inst|
        inst.transformation = inst.transformation * r_scale_inv
      end
      Debug.log(self, :align_pca, "scale baked: (#{sx.round(4)}, #{sy.round(4)}, #{sz.round(4)})")
    end

    # BB volume of pts rotated by a row-major 3×3 matrix (no allocation in inner loop).
    def self.bb_vol_3d(pts, r00, r01, r02, r10, r11, r12, r20, r21, r22)
      p0 = pts[0]
      qx = r00*p0.x + r01*p0.y + r02*p0.z
      qy = r10*p0.x + r11*p0.y + r12*p0.z
      qz = r20*p0.x + r21*p0.y + r22*p0.z
      xmin = xmax = qx; ymin = ymax = qy; zmin = zmax = qz
      pts.each do |p|
        qx = r00*p.x + r01*p.y + r02*p.z
        qy = r10*p.x + r11*p.y + r12*p.z
        qz = r20*p.x + r21*p.y + r22*p.z
        xmin = qx if qx < xmin; xmax = qx if qx > xmax
        ymin = qy if qy < ymin; ymax = qy if qy > ymax
        zmin = qz if qz < zmin; zmax = qz if qz > zmax
      end
      (xmax - xmin) * (ymax - ymin) * (zmax - zmin)
    end

    # Returns the unit plane normal [nx,ny,nz] if all pts are coplanar
    # (max off-plane deviation < 1e-4 * max span), otherwise nil.
    def self.planar_normal(pts)
      return nil if pts.size < 3

      ext = [:x,:y,:z].flat_map { |ax|
        [pts.each_with_index.min_by{|p,_| p.send(ax)}[1],
         pts.each_with_index.max_by{|p,_| p.send(ax)}[1]]
      }.uniq

      i0, i1 = ext.combination(2).max_by { |a,b|
        pa=pts[a]; pb=pts[b]; (pa.x-pb.x)**2+(pa.y-pb.y)**2+(pa.z-pb.z)**2
      }
      span2 = (pts[i0].x-pts[i1].x)**2+(pts[i0].y-pts[i1].y)**2+(pts[i0].z-pts[i1].z)**2
      return nil if span2 < 1e-12

      la=pts[i0]; lb=pts[i1]; ddx=lb.x-la.x; ddy=lb.y-la.y; ddz=lb.z-la.z

      i2 = (0...pts.size).reject{|i|i==i0||i==i1}.max_by { |i|
        p=pts[i]; ex=p.x-la.x; ey=p.y-la.y; ez=p.z-la.z
        cx=ddy*ez-ddz*ey; cy=ddz*ex-ddx*ez; cz=ddx*ey-ddy*ex; cx*cx+cy*cy+cz*cz
      }
      return nil unless i2

      a=pts[i0]; b=pts[i1]; c=pts[i2]
      ux=b.x-a.x; uy=b.y-a.y; uz=b.z-a.z
      vx=c.x-a.x; vy=c.y-a.y; vz=c.z-a.z
      nx=uy*vz-uz*vy; ny=uz*vx-ux*vz; nz=ux*vy-uy*vx
      nl=Math.sqrt(nx*nx+ny*ny+nz*nz)
      return nil if nl < 1e-12
      nx/=nl; ny/=nl; nz/=nl

      max_dev = 0.0
      pts.each do |p|
        d = (nx*(p.x-a.x) + ny*(p.y-a.y) + nz*(p.z-a.z)).abs
        max_dev = d if d > max_dev
      end

      max_dev / Math.sqrt(span2) < 1e-4 ? [nx, ny, nz] : nil
    end

    # Permutes and/or flips local axes by picking the best of the 24 proper
    # rotations of the cube (6 permutations × 4 right-handed sign combinations).
    # Scoring depends on whether pre-alignment axes are provided:
    #   - If z_pre/x_pre given: primary = alignment with pre-axes (×100),
    #     secondary = extent ordering (X largest, Z smallest) as tiebreaker.
    #     Keeps the instance axes close to their pre-op orientation.
    #   - Otherwise: primary = extent ordering (×100),
    #     secondary = alignment with world axes.
    # Must be called after geometry is in definition space.
    def self.permute_axes_by_extent(instance, z_pre = nil, x_pre = nil)
      pts = collect_vertices(instance.definition.entities, Geom::Transformation.new)
      return if pts.empty?

      xs = pts.map(&:x); ys = pts.map(&:y); zs = pts.map(&:z)
      dx = xs.max - xs.min; dy = ys.max - ys.min; dz = zs.max - zs.min

      mean_ext = (dx + dy + dz) / 3.0
      tol      = [mean_ext * 5e-3, 1e-6].max
      buckets  = [dx, dy, dz].map { |e| (e / tol).round }

      t        = instance.transformation
      inst_det = t.xaxis.dot(t.yaxis.cross(t.zaxis)) >= 0 ? 1 : -1
      # For LH instances negate X before world-axis scoring so the search sees
      # the "equivalent RH" axes → same permutation+signs as the RH counterpart.
      # Proper rotations (det=+1) are used regardless, so handedness is preserved.
      ax = inst_det < 0 ? Geom::Vector3d.new(-t.xaxis.x, -t.xaxis.y, -t.xaxis.z) : t.xaxis
      axes     = [ax, t.yaxis, t.zaxis]
      raw_axes = [t.xaxis, t.yaxis, t.zaxis]
      use_pre  = z_pre && x_pre

      best_score = -Float::INFINITY
      best_perm  = [0, 1, 2]
      best_signs = [1, 1, 1]

      # perm_det: determinant of the permutation matrix (+1 even, -1 odd).
      # We always use proper rotations (det(R_norm)=+1) so that handedness is
      # preserved: LH instances stay LH, RH instances stay RH.
      # det(R_norm) = perm_det * sign_product = +1  →  sign_product = perm_det
      [[[0,1,2], 1],[[0,2,1],-1],[[1,0,2],-1],
       [[1,2,0], 1],[[2,0,1], 1],[[2,1,0],-1]].each do |perm, pd|
        (pd > 0 ? [[1,1,1],[1,-1,-1],[-1,1,-1],[-1,-1,1]]
                : [[-1,1,1],[1,-1,1],[1,1,-1],[-1,-1,-1]]).each do |sx, sy, sz|
          if use_pre
            # Primary: how well new X and new Z match pre-orientation.
            align_pre = sx * raw_axes[perm[0]].dot(x_pre) +
                        sz * raw_axes[perm[2]].dot(z_pre)
            ext_order  = (buckets[perm[0]] >= buckets[perm[1]] ? 1 : -1)
            ext_order += (buckets[perm[1]] >= buckets[perm[2]] ? 1 : -1)
            score = 100 * align_pre + ext_order
          else
            ext_score  = (buckets[perm[0]] >= buckets[perm[1]] ? 100 : -100)
            ext_score += (buckets[perm[1]] >= buckets[perm[2]] ? 100 : -100)
            align = sx * axes[perm[0]].x + sy * axes[perm[1]].y + sz * axes[perm[2]].z
            score = ext_score + align
          end

          if score > best_score
            best_score = score; best_perm = perm; best_signs = [sx, sy, sz]
          end
        end
      end

      return if best_perm == [0, 1, 2] && best_signs == [1, 1, 1]

      # Build column-major SketchUp transform from permutation + signs.
      # R[i,j] = signs[i] * delta(j, perm[i])  →  col j has one nonzero at row inv_perm[j].
      inv_perm = [nil, nil, nil]; 3.times { |i| inv_perm[best_perm[i]] = i }
      arr = Array.new(16, 0.0); arr[15] = 1.0
      3.times { |col| row = inv_perm[col]; arr[col * 4 + row] = best_signs[row].to_f }
      r_transform = Geom::Transformation.new(arr)
      r_inv       = r_transform.inverse

      instance.definition.entities.transform_entities(r_transform, instance.definition.entities.to_a)
      instance.definition.instances.each do |inst|
        inst.transformation = inst.transformation * r_inv
      end
      Debug.log(self, :align_pca, "axes normalized: perm=#{best_perm} signs=(#{best_signs.join(',')})")
    end

    # Redefines the local axes to minimize the bounding box volume (3D) or area
    # (2D flat geometry). Uses a two-phase ZYZ Euler sweep + Nelder-Mead for 3D,
    # or normal alignment + 1D sweep for flat/planar geometry.
    # Geometry stays in world position.
    def self.align_to_min_bb(instance, z_pre = nil, x_pre = nil)
      method_id  = __method__
      start_time = Time.now
      Debug.log(self, method_id, "Process START")

      begin
      # Isolate siblings so modifying the definition only affects this instance,
      # and bake non-uniform scale so collect_vertices reflects the scaled shape.
      instance.make_unique if instance.is_a?(Sketchup::Group) && instance.definition.instances.size > 1
      bake_scale(instance)

      # Work in definition space (identity frame). This makes the algorithm
      # idempotent: after applying, the next call sees already-rotated pts
      # and the sweep returns identity → no further change.
      id = Geom::Transformation.new
      pts = collect_vertices(instance.definition.entities, id)
      t0  = instance.transformation
      det0 = t0.xaxis.dot(t0.yaxis.cross(t0.zaxis)) >= 0 ? "RH" : "LH"
      Debug.log(self, :align_pca, "instance=#{instance.definition.name} pts=#{pts.size} handedness=#{det0}")
      return if pts.empty?

      hull_pts, hull_faces = convex_hull_3d_with_faces(pts)
      pts = hull_pts
      Debug.log(self, :align_pca, "hull pts=#{hull_pts.size} faces=#{hull_faces.size}")

      deg2rad = Math::PI / 180.0

      # ── 2D path: flat/planar geometry ──────────────────────────────────────
      normal = planar_normal(pts)
      if normal
        nx, ny, nz = normal
        Debug.log(self, :align_pca, "planar geometry, normal=[#{nx.round(4)},#{ny.round(4)},#{nz.round(4)}]")

        # Nearest world axis to the normal (preserve sign so local Z matches normal)
        axis_idx  = [[nx.abs, 0],[ny.abs, 1],[nz.abs, 2]].max_by{|v,_| v}[1]
        axes      = [[1,0,0],[0,1,0],[0,0,1]]
        ax, ay, az = axes[axis_idx]
        # Flip target axis if normal points opposite to it
        ax, ay, az = -ax, -ay, -az if (nx*ax + ny*ay + nz*az) < 0

        # Rodrigues rotation: map normal → world axis
        # rot_axis = normal × axis_vec,  angle = atan2(|cross|, dot)
        rax = ny*az - nz*ay
        ray = nz*ax - nx*az
        raz = nx*ay - ny*ax
        rl  = Math.sqrt(rax*rax + ray*ray + raz*raz)
        cos_a = nx*ax + ny*ay + nz*az
        orig  = Geom::Point3d.new(0,0,0)
        if rl < 1e-8
          # Normal already aligned (or anti-aligned) with world axis
          if cos_a >= 0
            r1 = Geom::Transformation.new
          else
            # 180° around any perpendicular axis
            px = 1 - nx*nx; py = -nx*ny; pz = -nx*nz
            if (px*px+py*py+pz*pz) < 0.5
              px = -ny*nx; py = 1 - ny*ny; pz = -ny*nz
            end
            pl  = Math.sqrt(px*px+py*py+pz*pz)
            r1  = Geom::Transformation.rotation(orig, Geom::Vector3d.new(px/pl,py/pl,pz/pl), Math::PI)
          end
        else
          rot_vec = Geom::Vector3d.new(rax/rl, ray/rl, raz/rl)
          r1 = Geom::Transformation.rotation(orig, rot_vec, Math.atan2(rl, cos_a))
        end

        # Transform pts into the axis-aligned frame
        pts1 = pts.map { |p| r1 * p }

        # Extract 2D coords by dropping the flat axis
        pts2d = pts1.map { |p|
          case axis_idx
          when 2 then [p.x, p.y]
          when 0 then [p.y, p.z]
          when 1 then [p.x, p.z]
          end
        }

        # 2D convex hull via Graham scan
        i0 = pts2d.each_with_index.min_by { |p, _| [p[1], p[0]] }[1]
        ox, oy = pts2d[i0]
        sorted = pts2d.each_with_index
                      .reject { |_, i| i == i0 }
                      .sort_by { |p, _| [Math.atan2(p[1]-oy, p[0]-ox), (p[0]-ox)**2+(p[1]-oy)**2] }
        hull2d = [[ox, oy]]
        sorted.each do |p, _|
          hull2d << p
          while hull2d.size >= 3
            a2 = hull2d[-3]; b2 = hull2d[-2]; c2 = hull2d[-1]
            cross = (b2[0]-a2[0])*(c2[1]-a2[1]) - (b2[1]-a2[1])*(c2[0]-a2[0])
            break if cross > 0
            hull2d.delete_at(-2)
          end
        end

        # Eval 2D bounding-box area after rotating by theta around axis_idx axis
        area_at = lambda do |theta|
          cos_t = Math.cos(theta); sin_t = Math.sin(theta)
          case axis_idx
          when 2  # flat=Z, sweep in XY
            u = pts1.map { |p| p.x*cos_t - p.y*sin_t }
            v = pts1.map { |p| p.x*sin_t + p.y*cos_t }
          when 0  # flat=X, sweep in YZ
            u = pts1.map { |p| p.y*cos_t - p.z*sin_t }
            v = pts1.map { |p| p.y*sin_t + p.z*cos_t }
          when 1  # flat=Y, sweep in XZ
            u = pts1.map { |p| p.x*cos_t + p.z*sin_t }
            v = pts1.map { |p|-p.x*sin_t + p.z*cos_t }
          end
          (u.max - u.min) * (v.max - v.min)
        end

        # Rotating calipers: the minimum-area BB of a convex polygon always has
        # one side flush with an edge → only need to evaluate at edge angles.
        # BB area has period π/2, so normalize angles to [0, π/2).
        half_pi = Math::PI / 2.0
        edge_angles = hull2d.each_with_index.map { |p, i|
          q = hull2d[(i + 1) % hull2d.size]
          (-Math.atan2(q[1]-p[1], q[0]-p[0])) % half_pi
        }.uniq

        fine_angle = 0.0
        fine_area  = area_at.call(0.0)
        edge_angles.each do |a|
          area = area_at.call(a)
          fine_angle = a; fine_area = area if area < fine_area
        end
        Debug.log(self, :align_pca, "2D rotating-calipers best=#{(fine_angle/deg2rad).round(3)}° area=#{fine_area.round(4)} (#{edge_angles.size} edges)")

        # Compose r1 (normal align) + r2 (in-plane rotation)
        flat_axis_vec = Geom::Vector3d.new(*axes[axis_idx])
        r2      = Geom::Transformation.rotation(orig, flat_axis_vec, fine_angle)
        r_total = r2 * r1

        # Skip if total rotation is negligible (< 0.006°)
        m = r_total.to_a
        trace = m[0] + m[5] + m[10]
        total_angle = Math.acos([[(trace - 1.0) / 2.0, -1.0].max, 1.0].min)
        if total_angle < 1e-4
          Debug.log(self, :align_pca, "already optimal (2D)")
          return
        end

        r_total_inv = r_total.inverse
        instance.definition.entities.transform_entities(r_total, instance.definition.entities.to_a)
        instance.definition.instances.each do |inst|
          before = inst.transformation.origin
          inst.transformation = inst.transformation * r_total_inv
          after  = inst.transformation.origin
          Debug.log(self, :align_pca, "  origin: #{before.to_a.map{|v|v.round(3)}} → #{after.to_a.map{|v|v.round(3)}}")
        end
        permute_axes_by_extent(instance, z_pre, x_pre)
        t1 = instance.transformation
        det1 = t1.xaxis.dot(t1.yaxis.cross(t1.zaxis)) >= 0 ? "RH" : "LH"
        Debug.log(self, :align_pca, "done (2D) handedness=#{det1}")
        return
      end

      # ── 3D path: auto-dispatch by hull size ────────────────────────────────
      # Face-flush (O'Rourke): O(F·N²) but N small → fast on polyhedral objects.
      # ZYZ + Nelder-Mead: O(K·N) with fixed K → wins as hull size grows.
      # Crossover empirically at ~300 hull points.
      deg2rad = Math::PI / 180.0
      fine_vol = nil
      r_best   = nil

      if hull_pts.size < 300 && !hull_faces.empty?
        # Face-flush heuristic over hull faces
        best = face_flush_min_bb(pts, hull_faces)
        if best.nil?
          Debug.log(self, :align_pca, "face-flush: no valid candidate")
          return
        end
        r11, r12, r13, r21, r22, r23, r31, r32, r33, fine_vol = best
        Debug.log(self, :align_pca, "face-flush best vol=#{fine_vol.round(4)}")

        # Row-major R → column-major for SketchUp
        r_best = Geom::Transformation.new([
          r11, r21, r31, 0,
          r12, r22, r32, 0,
          r13, r23, r33, 0,
          0,   0,   0,   1
        ])
      else
        # ZYZ Euler angles: R = Rz(α) * Ry(β) * Rz(γ)
        # Matrix rows:
        #   [ca*cb*cg - sa*sg,  -ca*cb*sg - sa*cg,  ca*sb]
        #   [sa*cb*cg + ca*sg,  -sa*cb*sg + ca*cg,  sa*sb]
        #   [-sb*cg,             sb*sg,              cb   ]
        # BB has 90° period in α and γ → search [0°,90°) × [-90°,90°) × [0°,90°)
        eval_zyz = lambda do |al, be, ga|
          ca = Math.cos(al); sa = Math.sin(al)
          cb = Math.cos(be); sb = Math.sin(be)
          cg = Math.cos(ga); sg = Math.sin(ga)
          bb_vol_3d(pts,
            ca*cb*cg - sa*sg,  -ca*cb*sg - sa*cg,  ca*sb,
            sa*cb*cg + ca*sg,  -sa*cb*sg + ca*cg,  sa*sb,
            -sb*cg,             sb*sg,              cb)
        end

        # Phase 1: coarse grid 15° → 6×12×6 = 432 evals to find basin
        best_al = 0.0; best_be = 0.0; best_ga = 0.0
        best_vol = Float::INFINITY
        (0...90).step(15) do |ad|
          (-90...90).step(15) do |bd|
            (0...90).step(15) do |gd|
              vol = eval_zyz.call(ad*deg2rad, bd*deg2rad, gd*deg2rad)
              if vol < best_vol
                best_vol = vol; best_al = ad*deg2rad; best_be = bd*deg2rad; best_ga = gd*deg2rad
              end
            end
          end
        end
        Debug.log(self, :align_pca, "coarse best=α#{(best_al/deg2rad).round(1)}° β#{(best_be/deg2rad).round(1)}° γ#{(best_ga/deg2rad).round(1)}° vol=#{best_vol.round(4)}")

        # Phase 2: Nelder-Mead simplex from coarse best → converges to exact minimum
        # Simplex: 4 vertices in (α,β,γ) space, initial edge = 8°
        s = 8.0 * deg2rad
        simplex = [
          [best_al,       best_be,       best_ga      ],
          [best_al + s,   best_be,       best_ga      ],
          [best_al,       best_be + s,   best_ga      ],
          [best_al,       best_be,       best_ga + s  ],
        ]
        fval = simplex.map { |v| eval_zyz.call(*v) }

        # Safety cap: in practice NM converges in <50 iters with 1e-5 tolerance.
        # The 500 limit only triggers on degenerate input (e.g. near-collinear pts).
        500.times do
          order = fval.each_with_index.sort_by { |f, _| f }.map(&:last)
          simplex = order.map { |i| simplex[i] }
          fval    = order.map { |i| fval[i] }

          break if (fval.last - fval.first).abs < 1e-5

          c = [0.0, 0.0, 0.0]
          3.times { |i| 3.times { |d| c[d] += simplex[i][d] / 3.0 } }

          worst = simplex[3]; fw = fval[3]

          xr  = c.each_with_index.map { |ci, d| 2*ci - worst[d] }
          fxr = eval_zyz.call(*xr)

          if fxr < fval[0]
            xe  = c.each_with_index.map { |ci, d| 3*ci - 2*worst[d] }
            fxe = eval_zyz.call(*xe)
            if fxe < fxr
              simplex[3] = xe; fval[3] = fxe
            else
              simplex[3] = xr; fval[3] = fxr
            end
          elsif fxr < fval[2]
            simplex[3] = xr; fval[3] = fxr
          else
            xc  = c.each_with_index.map { |ci, d| 0.5*(ci + worst[d]) }
            fxc = eval_zyz.call(*xc)
            if fxc < fw
              simplex[3] = xc; fval[3] = fxc
            else
              best = simplex[0]
              1.upto(3) do |i|
                simplex[i] = simplex[i].each_with_index.map { |v, d| 0.5*(v + best[d]) }
                fval[i]    = eval_zyz.call(*simplex[i])
              end
            end
          end
        end

        fine_al, fine_be, fine_ga = simplex[0]
        fine_vol = fval[0]
        Debug.log(self, :align_pca, "nelder-mead best=α#{(fine_al/deg2rad).round(3)}° β#{(fine_be/deg2rad).round(3)}° γ#{(fine_ga/deg2rad).round(3)}° vol=#{fine_vol.round(4)}")

        ca = Math.cos(fine_al); sa = Math.sin(fine_al)
        cb = Math.cos(fine_be); sb = Math.sin(fine_be)
        cg = Math.cos(fine_ga); sg = Math.sin(fine_ga)

        # Best rotation in definition space (column-major for SketchUp)
        r_best = Geom::Transformation.new([
          ca*cb*cg - sa*sg,   sa*cb*cg + ca*sg,  -sb*cg,  0,
          -ca*cb*sg - sa*cg,  -sa*cb*sg + ca*cg,  sb*sg,  0,
          ca*sb,               sa*sb,              cb,     0,
          0, 0, 0, 1
        ])
      end

      # ── Shared apply tail ──────────────────────────────────────────────────
      current_vol = bb_vol_3d(pts, 1,0,0, 0,1,0, 0,0,1)
      if fine_vol >= current_vol * 0.99
        Debug.log(self, :align_pca, "already optimal (improvement < 1%)")
        return
      end

      r_best_inv = r_best.inverse
      instance.definition.entities.transform_entities(r_best, instance.definition.entities.to_a)
      instance.definition.instances.each do |inst|
        before = inst.transformation.origin
        inst.transformation = inst.transformation * r_best_inv
        after  = inst.transformation.origin
        Debug.log(self, :align_pca, "  origin: #{before.to_a.map{|v|v.round(3)}} → #{after.to_a.map{|v|v.round(3)}}")
      end
      permute_axes_by_extent(instance, z_pre, x_pre)
      t1 = instance.transformation
      det1 = t1.xaxis.dot(t1.yaxis.cross(t1.zaxis)) >= 0 ? "RH" : "LH"
      Debug.log(self, :align_pca, "done handedness=#{det1}")
        Debug.log(self, method_id, "Process DONE")
      rescue => e
        Debug.log(self, method_id, "Process ERROR. #{e.message}")
        Debug.log(self, method_id, e.backtrace.join("\n"))
        raise
      ensure
        elapsed = Time.now - start_time
        Debug.log(self, method_id, "Elapsed time: #{format('%.3f', elapsed)} sec.")
      end
    end

    # Constrained axis alignment: rotates the definition so that the given
    # face normal (in world space) ends up opposite to the chosen local axis.
    # The remaining rotational DoF is resolved via the minimum-angle rotation
    # (Rodrigues), which also minimises angular deviation of the other two
    # local axes from their pre-op directions.
    #   lock_axis : :x, :y, :z — the local axis that should point opposite n̂
    # Reorients the instance so the chosen local axis points along the given
    # world direction (face outward normal or edge vector), AND the remaining
    # two axes are rolled around the locked axis to minimize the in-plane
    # bounding box area. World geometry stays put; only the local axes (and
    # definition points) change.
    def self.align_to_direction_lock(instance, dir_world, lock_axis, z_pre = nil, x_pre = nil)
      method_id  = __method__
      start_time = Time.now
      Debug.log(self, method_id, "Process START lock=#{lock_axis}")

      begin
      instance.make_unique if instance.is_a?(Sketchup::Group) && instance.definition.instances.size > 1
      bake_scale(instance)

      t  = instance.transformation
      nl = Math.sqrt(dir_world.x**2 + dir_world.y**2 + dir_world.z**2)
      return if nl < 1e-12
      n_hat = Geom::Vector3d.new(dir_world.x / nl, dir_world.y / nl, dir_world.z / nl)

      unless [:x, :y, :z].include?(lock_axis)
        Debug.log(self, method_id, "invalid lock_axis=#{lock_axis.inspect}")
        return
      end

      world_pts = collect_vertices(instance.definition.entities, t)
      return if world_pts.empty?
      hull3d = convex_hull_3d(world_pts)
      hull3d = world_pts if hull3d.nil? || hull3d.size < 3

      # Orthonormal basis (u0, v0, n_hat) spanning the face plane.
      fb = n_hat.z.abs > 0.9 ? Geom::Vector3d.new(1, 0, 0) : Geom::Vector3d.new(0, 0, 1)
      u0_raw = n_hat.cross(fb)
      ul = Math.sqrt(u0_raw.x**2 + u0_raw.y**2 + u0_raw.z**2)
      return if ul < 1e-12
      u0 = Geom::Vector3d.new(u0_raw.x / ul, u0_raw.y / ul, u0_raw.z / ul)
      v0 = n_hat.cross(u0)  # already unit (n_hat ⟂ u0 & both unit)

      proj = hull3d.map { |p| [p.x*u0.x + p.y*u0.y + p.z*u0.z, p.x*v0.x + p.y*v0.y + p.z*v0.z] }
      hull2d = convex_hull_2d(proj)
      return if hull2d.size < 2

      # Rotating calipers: edge-aligned rect with minimum area.
      best_area = Float::INFINITY
      best_cos  = 1.0
      best_sin  = 0.0
      hull2d.each_with_index do |pa, i|
        pb = hull2d[(i + 1) % hull2d.size]
        ex = pb[0] - pa[0]; ey = pb[1] - pa[1]
        el = Math.sqrt(ex*ex + ey*ey)
        next if el < 1e-12
        c = ex / el; s = ey / el
        min_u = min_v = Float::INFINITY
        max_u = max_v = -Float::INFINITY
        hull2d.each do |p|
          pu =  p[0]*c + p[1]*s
          pv = -p[0]*s + p[1]*c
          min_u = pu if pu < min_u
          max_u = pu if pu > max_u
          min_v = pv if pv < min_v
          max_v = pv if pv > max_v
        end
        area = (max_u - min_u) * (max_v - min_v)
        if area < best_area
          best_area = area; best_cos = c; best_sin = s
        end
      end

      # Optimized in-plane basis.
      u_opt = Geom::Vector3d.new(
        best_cos * u0.x + best_sin * v0.x,
        best_cos * u0.y + best_sin * v0.y,
        best_cos * u0.z + best_sin * v0.z
      )
      v_opt = Geom::Vector3d.new(
        -best_sin * u0.x + best_cos * v0.x,
        -best_sin * u0.y + best_cos * v0.y,
        -best_sin * u0.z + best_cos * v0.z
      )

      neg_u = Geom::Vector3d.new(-u_opt.x, -u_opt.y, -u_opt.z)
      neg_v = Geom::Vector3d.new(-v_opt.x, -v_opt.y, -v_opt.z)

      # Four 90° rotations of the non-locked axes. Pair (a, b) always satisfies a×b = n_hat.
      rot_pairs = [[u_opt, v_opt], [v_opt, neg_u], [neg_u, neg_v], [neg_v, u_opt]]

      y_pre = nil
      if z_pre && x_pre
        y_pre = Geom::Vector3d.new(
          z_pre.y * x_pre.z - z_pre.z * x_pre.y,
          z_pre.z * x_pre.x - z_pre.x * x_pre.z,
          z_pre.x * x_pre.y - z_pre.y * x_pre.x
        )
      end

      best_xw = best_yw = best_zw = nil
      best_score = -Float::INFINITY
      rot_pairs.each do |a, b|
        case lock_axis
        when :x then xw, yw, zw = n_hat, a, b
        when :y then xw, yw, zw = b, n_hat, a
        when :z then xw, yw, zw = a, b, n_hat
        end

        if y_pre
          score = xw.dot(x_pre) + yw.dot(y_pre) + zw.dot(z_pre)
        else
          # Extent ordering: X ≥ Y ≥ Z.
          min_x = min_y = min_z = Float::INFINITY
          max_x = max_y = max_z = -Float::INFINITY
          hull3d.each do |p|
            px = p.x*xw.x + p.y*xw.y + p.z*xw.z
            py = p.x*yw.x + p.y*yw.y + p.z*yw.z
            pz = p.x*zw.x + p.y*zw.y + p.z*zw.z
            min_x = px if px < min_x; max_x = px if px > max_x
            min_y = py if py < min_y; max_y = py if py > max_y
            min_z = pz if pz < min_z; max_z = pz if pz > max_z
          end
          dx = max_x - min_x; dy = max_y - min_y; dz = max_z - min_z
          score = 0
          score += 1 if dx >= dy
          score += 1 if dy >= dz
        end

        if score > best_score
          best_score = score
          best_xw = xw; best_yw = yw; best_zw = zw
        end
      end

      # Build target transformation (same origin, new orthonormal axes).
      arr = [
        best_xw.x, best_xw.y, best_xw.z, 0.0,
        best_yw.x, best_yw.y, best_yw.z, 0.0,
        best_zw.x, best_zw.y, best_zw.z, 0.0,
        t.origin.x, t.origin.y, t.origin.z, 1.0
      ]
      t_new = Geom::Transformation.new(arr)
      r     = t_new.inverse * t
      r_inv = r.inverse

      instance.definition.entities.transform_entities(r, instance.definition.entities.to_a)
      instance.definition.instances.each do |i|
        i.transformation = i.transformation * r_inv
      end

      Debug.log(self, method_id, "min rect area=#{best_area.round(4)}")
      Debug.log(self, method_id, "Process DONE")
      rescue => e
        Debug.log(self, method_id, "Process ERROR. #{e.message}")
        Debug.log(self, method_id, e.backtrace.join("\n"))
        raise
      ensure
        elapsed = Time.now - start_time
        Debug.log(self, method_id, "Elapsed time: #{format('%.3f', elapsed)} sec.")
      end
    end

    # Tool class that runs align_to_min_bb in one operation.
    # Recurrent: stays active for repeated clicks.
    class OEAlignOptimalTool

      BB_EDGES = [[0,1],[0,2],[1,3],[2,3],[4,5],[4,6],[5,7],[6,7],[0,4],[1,5],[2,6],[3,7]].freeze

      # TAB cycles: auto → Z (XY plane) → X (YZ plane) → Y (XZ plane) → auto
      LOCK_CYCLE = [:auto, :z, :x, :y].freeze

      # Mode colors match SketchUp axis convention (X=red, Y=green, Z=blue).
      MODE_COLOR = {
        z: Sketchup::Color.new(50, 100, 255),
        x: Sketchup::Color.new(255, 80, 80),
        y: Sketchup::Color.new(50, 180, 50),
      }.freeze

      @@last_lock_mode = :auto

      def self.cursor_id
        @@cursor_id ||= begin
          ext  = Sketchup.platform == :platform_win ? 'svg' : 'pdf'
          path = File.join(PATH_CURSORS, "oe_optimize_32.#{ext}")
          UI.create_cursor(path, 5, 5)
        end
      end

      def initialize(instances)
        @model          = Sketchup.active_model
        @instances      = instances
        @hovered        = nil
        @lock_mode      = @@last_lock_mode
        @alt_handled    = false
        @hover_kind     = nil   # :face | :edge | nil
        @hover_entity   = nil   # Sketchup::Face or Sketchup::Edge
        @hover_loops    = nil   # Array of Array<Point3d> (face outer + inner loops, world)
        @hover_segment  = nil   # [Point3d, Point3d] (edge endpoints, world)
        @hover_dir      = nil   # Vector3d (locked-axis direction, world)
        @hover_fill_pts = nil   # Flat Array<Point3d>, 3 per triangle (face mesh triangulation)
        @hover_centroid = nil   # Point3d (face centroid or edge midpoint, world)
      end

      def activate
        @model.selection.clear unless @model.selection.empty?
        update_vcb
        UI.start_timer(0, false) { apply_auto(@instances) unless @instances.empty? }
      end

      def deactivate(view)
        clear_hover
        view.invalidate
      end

      def resume(_view)
        update_vcb
      end

      def suspend(view)
        clear_hover
        view.invalidate
      end

      def onMouseMove(_flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)

        if @lock_mode == :auto
          entity = ph.best_picked
          candidate = (entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)) ? entity : nil
          if candidate != @hovered
            @hovered = candidate
            clear_hover_geom
            view.invalidate
          end
        else
          leaf = nil; outer = nil; t_world = nil
          ph.count.times do |i|
            cand_leaf = ph.leaf_at(i)
            next unless cand_leaf.is_a?(Sketchup::Face) || cand_leaf.is_a?(Sketchup::Edge)
            path = ph.path_at(i) || []
            candidate = path.first
            next unless candidate.is_a?(Sketchup::ComponentInstance) || candidate.is_a?(Sketchup::Group)
            leaf    = cand_leaf
            outer   = candidate
            t_world = ph.transformation_at(i)
            break
          end

          changed = (leaf != @hover_entity) || (outer != @hovered)
          if changed
            @hover_entity = leaf
            @hovered      = outer
            clear_hover_geom
            if leaf && t_world
              case leaf
              when Sketchup::Face then capture_hover_face(leaf, t_world)
              when Sketchup::Edge then capture_hover_edge(leaf, t_world)
              end
            end
            view.invalidate
          end
        end
      end

      def draw(view)
        eye = view.camera.eye

        if @hovered && @hovered.valid?
          bb_color = @lock_mode == :auto ? Sketchup::Color.new(255, 165, 0) : MODE_COLOR[@lock_mode]
          t        = @hovered.transformation
          def_bb   = @hovered.definition.bounds
          corners  = 8.times.map { |i| t * def_bb.corner(i) }
          view.line_width     = 2
          view.drawing_color  = bb_color
          BB_EDGES.each do |a, b|
            pa = corners[a].offset((eye - corners[a]).normalize, 0.1)
            pb = corners[b].offset((eye - corners[b]).normalize, 0.1)
            view.draw(GL_LINES, [pa, pb])
          end
        end

        return if @lock_mode == :auto
        return unless @hover_entity && @hover_entity.valid?

        color = MODE_COLOR[@lock_mode]

        case @hover_kind
        when :face
          return unless @hover_loops
          fill = Sketchup::Color.new(color.red, color.green, color.blue, 80)
          if @hover_fill_pts && !@hover_fill_pts.empty?
            view.drawing_color = fill
            view.draw(GL_TRIANGLES, @hover_fill_pts)
          end
          view.line_width    = 3
          view.drawing_color = color
          @hover_loops.each do |loop_pts|
            offset_pts = loop_pts.map { |p| p.offset((eye - p).normalize, 0.1) }
            view.draw(GL_LINE_LOOP, offset_pts)
          end
        when :edge
          return unless @hover_segment
          view.line_width    = 5
          view.drawing_color = color
          seg = @hover_segment.map { |p| p.offset((eye - p).normalize, 0.1) }
          view.draw(GL_LINES, seg)
        end

        if @hover_kind == :face && @hover_centroid && @hover_dir
          len_ref = (@hovered && @hovered.valid?) ? @hovered.bounds.diagonal.to_f : 10.0
          len     = len_ref * 0.12
          p1      = @hover_centroid.offset((eye - @hover_centroid).normalize, 0.1)
          p2      = p1.offset(@hover_dir, len)
          view.line_width    = 4
          view.drawing_color = color
          view.draw(GL_LINES, [p1, p2])
        end
      end

      def getExtents
        bb = Geom::BoundingBox.new
        if @hovered && @hovered.valid?
          t = @hovered.transformation
          8.times { |i| bb.add(t * @hovered.definition.bounds.corner(i)) }
        end
        @hover_loops.each { |loop_pts| loop_pts.each { |p| bb.add(p) } } if @hover_loops
        @hover_segment.each { |p| bb.add(p) } if @hover_segment
        bb
      end

      def enableVCB?
        true
      end

      def onSetCursor
        UI.set_cursor(OEAlignOptimalTool.cursor_id)
      end

      def onLButtonDown(_flags, x, y, view)
        if @lock_mode == :auto
          ph = view.pick_helper
          ph.do_pick(x, y)
          entity = ph.best_picked
          return unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          apply_auto([entity])
        else
          return unless @hovered && @hovered.valid? && @hover_dir
          apply_lock(@hovered, @hover_dir, @lock_mode)
        end
      end

      def onKeyDown(key, _repeat, _flags, view)
        case key
        when 27 # Escape
          @model.select_tool(nil)
        when 18 # Alt — cycle mode
          cycle_mode(view)
          @alt_handled = true
        end
      end

      def onKeyUp(key, _repeat, _flags, view)
        if key == 18 # Alt — fallback if key-down was swallowed by the OS
          cycle_mode(view) unless @alt_handled
          @alt_handled = false
        end
      end

      private

      def cycle_mode(view)
        idx = LOCK_CYCLE.index(@lock_mode) || 0
        @lock_mode = LOCK_CYCLE[(idx + 1) % LOCK_CYCLE.size]
        @@last_lock_mode = @lock_mode
        clear_hover
        update_vcb
        view.invalidate
      end

      def clear_hover
        @hover_entity = nil
        clear_hover_geom
      end

      def clear_hover_geom
        @hover_kind     = nil
        @hover_loops    = nil
        @hover_segment  = nil
        @hover_dir      = nil
        @hover_fill_pts = nil
        @hover_centroid = nil
      end

      def capture_hover_face(face, t_world)
        loops = [face.outer_loop.vertices.map { |v| t_world * v.position }]
        face.loops.each { |l| loops << l.vertices.map { |v| t_world * v.position } unless l.outer? }

        mesh     = face.mesh
        fill_pts = []
        if mesh
          (1..mesh.count_polygons).each do |i|
            mesh.polygon_points_at(i).each { |p| fill_pts << (t_world * p) }
          end
        end

        outer_pts = loops.first
        cx = cy = cz = 0.0
        outer_pts.each { |p| cx += p.x; cy += p.y; cz += p.z }
        n_outer = outer_pts.size

        nw = t_world * face.normal
        nl = Math.sqrt(nw.x**2 + nw.y**2 + nw.z**2)
        return if nl < 1e-12

        @hover_kind     = :face
        @hover_loops    = loops
        @hover_fill_pts = fill_pts
        @hover_centroid = Geom::Point3d.new(cx / n_outer, cy / n_outer, cz / n_outer)
        @hover_dir      = Geom::Vector3d.new(nw.x / nl, nw.y / nl, nw.z / nl)
      end

      def capture_hover_edge(edge, t_world)
        a = t_world * edge.start.position
        b = t_world * edge.end.position
        dx = b.x - a.x; dy = b.y - a.y; dz = b.z - a.z
        dl = Math.sqrt(dx*dx + dy*dy + dz*dz)
        return if dl < 1e-12

        @hover_kind     = :edge
        @hover_segment  = [a, b]
        @hover_centroid = Geom::Point3d.new((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, (a.z + b.z) * 0.5)
        @hover_dir      = Geom::Vector3d.new(dx / dl, dy / dl, dz / dl)
      end

      def apply_auto(instances)
        return if instances.empty?
        # Capture Z and X axes before any modification.
        pre_axes = {}
        instances.each do |inst|
          next unless inst.valid?
          pre_axes[inst.object_id] = [inst.transformation.zaxis, inst.transformation.xaxis]
        end

        @model.start_operation("Orienter Express: Optimal Axis Alignment", true)
        begin
          instances.each do |inst|
            next unless inst.valid?
            z_pre, x_pre = pre_axes[inst.object_id]
            OrienterExpress.send(:align_to_min_bb, inst, z_pre, x_pre)
          end
          @model.commit_operation
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

      def apply_lock(instance, dir_world, lock_axis)
        z_pre = instance.transformation.zaxis
        x_pre = instance.transformation.xaxis
        @model.start_operation("Orienter Express: Direction-Lock Alignment", true)
        begin
          OrienterExpress.send(:align_to_direction_lock, instance, dir_world, lock_axis, z_pre, x_pre)
          clear_hover
          @model.commit_operation
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

      def update_vcb
        mode_label = case @lock_mode
                     when :auto then Lang.commands.oealignoptimal.mode_auto
                     when :z    then Lang.commands.oealignoptimal.mode_z
                     when :x    then Lang.commands.oealignoptimal.mode_x
                     when :y    then Lang.commands.oealignoptimal.mode_y
                     end
        hint = format(Lang.commands.oealignoptimal.vcb_hint.to_s, mode: mode_label.to_s)
        Sketchup.set_status_text(hint, 0)
      end
    end

    def self.oealignoptimal
      model   = Sketchup.active_model
      targets = instances(model.selection)
      model.select_tool(OEAlignOptimalTool.new(targets))
    end

    private_class_method :collect_vertices
    private_class_method :convex_hull_2d
    private_class_method :convex_hull_3d
    private_class_method :convex_hull_3d_with_faces
    private_class_method :face_flush_min_bb
    private_class_method :bb_vol_3d
    private_class_method :planar_normal
    private_class_method :permute_axes_by_extent
    private_class_method :align_to_min_bb
    private_class_method :align_to_direction_lock
    private_class_method :bake_scale
    private_class_method :orient_ground
    private_class_method :orient_ground_around
    private_class_method :orient_to_flow_around
    private_class_method :orient_to_face_normal_around
    private_class_method :orient_to_flow
    private_class_method :face_centroid
    private_class_method :resolved_insertion_point
    private_class_method :move_insertion_to
    private_class_method :vertex_flow_direction
    private_class_method :all_vertex_flow_directions

  end # module OrienterExpress
end # module ASM_Extensions
