module ASM_Extensions
  module OrienterExpress

    ### TRANSFORMATIONS ### -------------------------------------------------------

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

    def self.uniform_scale(entity, edge, axis = :z, target_length = nil)
      return unless instance?(entity)

      db      = entity.definition.bounds
      def_len = case axis
                when :x then (db.max.x - db.min.x).abs
                when :y then (db.max.y - db.min.y).abs
                else         (db.max.z - db.min.z).abs
                end
      return if def_len < 1e-6

      a   = entity.transformation.to_a
      col = case axis when :x then 0 when :y then 4 else 8 end
      current_s = Math.sqrt(a[col]**2 + a[col + 1]**2 + a[col + 2]**2)
      return if current_s < 1e-6

      length = target_length || edge.length
      factor = (length / def_len) / current_s
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
          # Near-antiparallel: cross product unreliable, pick any perpendicular axis.
          rotation_axis = local_n.cross(X_AXIS)
          rotation_axis = local_n.cross(Y_AXIS) if rotation_axis.length < 1e-3
        else
          rotation_axis = local_n.cross(target_n)
        end
      end

      return if rotation_axis.length < 1e-3

      rotation_transformation = Geom::Transformation.rotation(global_center, rotation_axis, angle)
      entity.transform!(rotation_transformation)
    end

    def self.orient_ground_around(entity, rotation_axis, target_axis)
      tolerance = 1e-6

      return if rotation_axis.length < tolerance
      return if target_axis.length < tolerance

      rot_axis    = rotation_axis.normalize
      target_norm = target_axis.normalize

      # Vertical rotation axis: can't change any axis's Z component.
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

    def self.orient_y(entity)
      orient_ground(entity, entity.transformation.yaxis)
    end

    def self.orient_x(entity)
      orient_ground(entity, entity.transformation.xaxis)
    end

    def self.orient_ground(entity, local_axis)
      transformation = entity.transformation
      z_axis         = transformation.zaxis
      tolerance      = 1e-6

      return if z_axis.length < tolerance
      return if local_axis.length < tolerance

      z_axis     = z_axis.normalize
      local_axis = local_axis.normalize

      # Z parallel to world Z: perpendicular axes already ground-parallel.
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

    def self.orient_to_flow(entity, edge, flow_map, h_dir_map = nil, dom_dirs = nil)
      # Vertical edges: flow projection to XY is degenerate; reuse the ground
      # tangent logic so all verticals on similarly-oriented walls share X.
      ev = edge.end.position - edge.start.position
      if ev.length > 1e-6 && ev.normalize.z.abs > 0.999
        return orient_x_ground(entity, edge, h_dir_map, dom_dirs)
      end
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

      dot       = z_axis.dot(avg)
      proj_z    = Geom::Vector3d.new(z_axis.x * dot, z_axis.y * dot, z_axis.z * dot)
      projected = avg - proj_z

      if projected.length < 1e-6
        orient_x(entity)
        return
      end

      target   = projected.normalize
      y_before = entity.transformation.yaxis.normalize

      # Signed angle: angle_between is unsigned, use cross · z_axis for sign.
      dot     = y_before.dot(target)
      cross   = y_before.cross(target)
      sin_val = cross.dot(z_axis.normalize)
      angle   = Math.atan2(sin_val, dot)

      unless angle.abs < 1e-6
        center = entity.bounds.center
        entity.transform!(Geom::Transformation.rotation(center, z_axis, angle))
      end
    end

    # Naked vertical edges are refined via h_dir_map so the component faces
    # the wall rather than defaulting to world X.
    def self.orient_to_face_normal(entity, edge, h_dir_map = nil)
      normals = edge.faces.map(&:normal).select { |n| n.length > 1e-6 }.map(&:normalize)
      if normals.empty?
        orient_x(entity)
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

    def self.orient_to_flow_around(entity, edge, flow_map, rot_axis_vec, face_axis_vec, h_dir_map = nil, dom_dirs = nil, scale_axis = nil)
      # Vertical edges: flow is degenerate; delegate to the matching ground helper.
      ev = edge.end.position - edge.start.position
      if ev.length > 1e-6 && ev.normalize.z.abs > 0.999 && scale_axis
        case scale_axis
        when :x then return orient_z_ground(entity, edge, h_dir_map, dom_dirs)
        when :y then return orient_y_ground(entity, edge, h_dir_map, dom_dirs)
        end
      end
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

    # For vertical edges orient_x is a no-op (all horizontal directions are
    # already ground-parallel); fall back to h_dir_map (vertex flow with BFS
    # sign propagation) for a geometry-intrinsic X that rotates with the mesh.
    def self.orient_x_ground(entity, edge = nil, h_dir_map = nil, dom_dirs = nil)
      orient_x(entity)
      return unless edge
      z = entity.transformation.zaxis.normalize
      return unless (z.z.abs - 1.0).abs < 1e-3   # only for near-vertical edges
      ref = horizontal_ref_for_vertical_edge(edge, h_dir_map, dom_dirs)
      return unless ref
      orient_x_to_horizontal(entity, ref)
      # ref is a face-normal-like direction; rotate 90° so X is tangent to the
      # wall (all verticals on a wall then share a coherent tangent axis).
      z2 = entity.transformation.zaxis.normalize
      entity.transform!(Geom::Transformation.rotation(entity.bounds.center, z2, 90.degrees))
    end

    # Priority: face normals of the edge's own faces (consistent per wall), then
    # "flow of normals" — sum of face normals at both vertices (catches naked
    # verticals adjacent to faced caps), then h_dir_map flow, then connected-edge
    # XY. When dom_dirs is provided, snaps the final ref to the nearest dominant
    # direction so all verticals on similarly-oriented walls share one X axis.
    def self.horizontal_ref_for_vertical_edge(edge, h_dir_map = nil, dom_dirs = nil)
      ref = nil

      normals = edge.faces.map(&:normal).select { |n| n.length > 1e-6 }
      unless normals.empty?
        avg = normals.reduce(Geom::Vector3d.new(0, 0, 0)) { |s, n| s + n }
        xy  = Geom::Vector3d.new(avg.x, avg.y, 0)
        ref = xy.normalize if xy.length > 1e-6
      end

      if ref.nil?
        sum  = Geom::Vector3d.new(0, 0, 0)
        seen = {}
        [edge.start, edge.end].each do |vertex|
          vertex.faces.each do |f|
            next if seen[f.entityID]
            seen[f.entityID] = true
            n  = f.normal
            xy = Geom::Vector3d.new(n.x, n.y, 0)
            sum = sum + xy if xy.length > 1e-6
          end
        end
        ref = sum.normalize if sum.length > 1e-6
      end

      if ref.nil? && h_dir_map
        [edge.start, edge.end].each do |v|
          d = h_dir_map[v]
          if d
            ref = d
            break
          end
        end
      end

      if ref.nil?
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
        ref = sum.normalize if sum.length > 1e-6
      end

      return nil unless ref
      snap_to_dominant(ref, dom_dirs)
    end

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

    # Ground mode (v2): align `scale_axis` to the face normal, then rotate
    # around it so the next axis in the XYZ cycle lies parallel to world XY.
    #   :z → Z↔normal, X horizontal
    #   :x → X↔normal, Y horizontal
    #   :y → Y↔normal, Z horizontal
    # When primary ends up parallel to world Z, all perpendicular axes are
    # already in the XY plane and no rotation is applied.
    def self.orient_ground_to_normal(entity, normal, scale_axis, dom_dirs = nil)
      return if normal.nil? || normal.length < 1e-6
      n = normal.normalize
      # For (near-)horizontal normals, snap to the dominant horizontal direction
      # so all verticals on similarly-oriented walls share one primary axis.
      if n.z.abs < 0.5 && dom_dirs && !dom_dirs.empty?
        snapped = snap_to_dominant(n, dom_dirs)
        n = snapped.normalize if snapped && snapped.length > 1e-6
      end
      t = entity.transformation
      primary_vec =
        case scale_axis
        when :x then t.xaxis
        when :y then t.yaxis
        else         t.zaxis
        end

      align_axis(entity, t.origin, primary_vec, n)

      t2 = entity.transformation
      primary, secondary =
        case scale_axis
        when :x then [t2.xaxis, t2.yaxis]
        when :y then [t2.yaxis, t2.zaxis]
        else         [t2.zaxis, t2.xaxis]
        end

      pn = primary.normalize
      return if pn.z.abs > 0.999

      horiz = pn.cross(Geom::Vector3d.new(0, 0, 1))
      return if horiz.length < 1e-6
      horiz = horiz.normalize

      sec_n  = secondary.normalize
      target = sec_n.dot(horiz) >= 0 ? horiz : horiz.reverse
      angle  = Math.atan2(sec_n.cross(target).dot(pn), sec_n.dot(target))
      return if angle.abs < 1e-6

      entity.transform!(Geom::Transformation.rotation(entity.bounds.center, pn, angle))
    end

    def self.orient_z_ground(entity, edge = nil, h_dir_map = nil, dom_dirs = nil)
      orient_ground_around(entity, entity.transformation.xaxis, entity.transformation.zaxis)
      return unless edge
      ref = horizontal_ref_for_vertical_edge(edge, h_dir_map, dom_dirs)
      orient_z_to_horizontal(entity, ref) if ref
    end

    def self.orient_y_ground(entity, edge = nil, h_dir_map = nil, dom_dirs = nil)
      orient_ground_around(entity, entity.transformation.yaxis, entity.transformation.zaxis)
      return unless edge
      ref = horizontal_ref_for_vertical_edge(edge, h_dir_map, dom_dirs)
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
    # Vertical edges → horizontal XY reference (wall). Horizontal/oblique edges
    # use the vertex flow's Z sign for cap surfaces, falling back to h_dir_map /
    # z_sign_map / connected-edge XY. Known limitation: rim vertices (wall/cap
    # junction) get ±Z instead of the bisector.
    def self.naked_edge_surface_normal(edge, h_dir_map = nil, z_sign_map = nil)
      dir = (edge.end.position - edge.start.position).normalize
      if dir.z.abs > 0.7
        horizontal_ref_for_vertical_edge(edge, h_dir_map)
      else
        [edge.start, edge.end].each do |vertex|
          d = vertex_flow_direction(vertex, vertex.edges.to_a)
          if d && d.z.abs > 0.3
            return Geom::Vector3d.new(0, 0, d.z > 0 ? 1 : -1)
          end
          ref = h_dir_map && h_dir_map[vertex]
          return ref if ref
          next if d && d.z.abs <= 0.3  # lateral flow — don't promote to ±Z
          ref = z_sign_map && z_sign_map[vertex]
          return ref if ref
        end
        horizontal_ref_for_vertical_edge(edge, h_dir_map)
      end
    end

    # Vertex → (0,0,±1) map. Sign from vertex flow for vertices on vertical
    # edges; propagated via BFS to interior vertices without vertical connectivity.
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

    # Greedy clustering of adjacent face-normal XYs (area-weighted); merges
    # directions within 15°. Returns up to max_k canonical XY directions, sorted
    # by total weight desc. Used to snap per-edge references so all verticals on
    # similarly-oriented walls share one X axis (octagon/curved cases).
    def self.dominant_horizontal_directions(geometry, max_k = 3)
      return [] unless geometry && !geometry.empty?
      seen  = {}
      faces = []
      geometry.each do |e|
        next unless e.is_a?(Sketchup::Edge) && e.valid?
        e.faces.each do |f|
          next if seen[f.entityID]
          seen[f.entityID] = true
          faces << f
        end
      end
      return [] if faces.empty?

      cos_thresh = Math.cos(15.0 * Math::PI / 180)
      clusters   = []
      faces.each do |f|
        n  = f.normal
        xy = Geom::Vector3d.new(n.x, n.y, 0)
        next if xy.length < 1e-6
        u = xy.normalize
        u = u.reverse if u.x < 0 || (u.x.abs < 1e-6 && u.y < 0)
        w = f.area
        hit = clusters.find { |c| c[0].dot(u).abs >= cos_thresh }
        if hit
          sign = hit[0].dot(u) >= 0 ? 1 : -1
          ux = hit[0].x * hit[1] + sign * u.x * w
          uy = hit[0].y * hit[1] + sign * u.y * w
          combined = Geom::Vector3d.new(ux, uy, 0)
          hit[0] = combined.length > 1e-6 ? combined.normalize : hit[0]
          hit[1] += w
        else
          clusters << [u, w]
        end
      end

      clusters.sort_by! { |c| -c[1] }
      clusters[0, max_k].map { |c| c[0] }
    end

    # Picks the dominant direction with max |ref·d|, signed to match ref, only
    # if ref is within ~30° of that direction. Otherwise returns ref unchanged —
    # this preserves bisectors (e.g. cube corners at 45°) where snapping would
    # arbitrarily pull toward one of two equidistant walls.
    SNAP_COS = Math.cos(30.0 * Math::PI / 180)
    def self.snap_to_dominant(ref, dom_dirs)
      return ref unless ref && dom_dirs && !dom_dirs.empty?
      rxy = Geom::Vector3d.new(ref.x, ref.y, 0)
      return ref if rxy.length < 1e-6
      rn = rxy.normalize
      best = nil
      best_abs = -1.0
      dom_dirs.each do |d|
        dot = rn.dot(d)
        if dot.abs > best_abs
          best_abs = dot.abs
          best = dot >= 0 ? d : d.reverse
        end
      end
      return ref if best_abs < SNAP_COS
      best || ref
    end

    private_class_method :horizontal_ref_for_vertical_edge, :orient_x_to_horizontal,
                         :orient_z_to_horizontal, :orient_z_ground, :orient_y_ground,
                         :naked_edge_surface_normal, :vertical_surface_directions,
                         :dominant_horizontal_directions, :snap_to_dominant

    # Stable, short ID for an edge, invariant under endpoint order.
    # Used for cross-referencing between runtime Debug.log and in-SketchUp
    # diagnostic scripts.
    def self.edge_id(edge)
      a = edge.start.position.to_a.map { |c| c.round(2) }
      b = edge.end.position.to_a.map { |c| c.round(2) }
      a, b = b, a if (b <=> a) < 0
      "#{a.join(',')}-#{b.join(',')}".hash.abs.to_s(36)[0, 6]
    end

    # Mirrors all_vertex_flow_directions but projects to XY, discarding entries
    # whose XY component is negligible (e.g. vertical normals from flat meshes).
    def self.horizontal_flow_directions(vertex_edges)
      reliable   = {}
      candidates = {}

      # Use ALL edges per vertex (not only selected ones) so corner vertices
      # get their true outward direction and strategy 3 finds non-parallel pairs.
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

      # BFS sign propagation from reliable to candidates via ALL connected
      # edges (so the signal reaches inner vertices with partial selections).
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

      result = {}
      reliable.merge(candidates).each do |vertex, dir|
        xy = Geom::Vector3d.new(dir.x, dir.y, 0)
        result[vertex] = xy.normalize if xy.length > 1e-6
      end
      result
    end
    private_class_method :horizontal_flow_directions

    # Returns [along, perp] in the face plane, or nil if degenerate.
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

    # axis_idx=0 → longest edge direction, axis_idx=1 → its perpendicular.
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

    # Deterministic edge direction: picks the component with the largest
    # absolute value and flips the vector so that component is positive.
    # Ties are broken by axis priority X > Y > Z. Ensures all collinear or
    # similarly-oriented edges resolve to the same forward direction, so
    # orientation and local-frame offsets stay consistent across a selection.
    def self.canonical_edge_dir(edge)
      v = edge.end.position - edge.start.position
      return v if v.length < 1e-12
      # Dot against a weighted reference (X ≫ Y ≫ Z) instead of branching on
      # dominant-component magnitude: the former branching was discontinuous
      # at ax == ay and flipped sign under floating-point noise (edges in a
      # 45°-rotated mesh landed in different branches, yielding opposite
      # canonical directions for parallel edges).
      score = v.x * 1.0 + v.y * 1e-3 + v.z * 1e-6
      score >= 0 ? v : v.reverse
    end

    def self.orient_z(instance, edge)
      edge_vector = canonical_edge_dir(edge)
      return if edge_vector.length < 1e-6
      align_axis(instance, instance.transformation.origin,
                 instance.transformation.zaxis, edge_vector.normalize)
    end

    def self.orient_x_to_edge(instance, edge)
      edge_vector = canonical_edge_dir(edge)
      return if edge_vector.length < 1e-6
      align_axis(instance, instance.transformation.origin,
                 instance.transformation.xaxis, edge_vector.normalize)
    end

    def self.orient_y_to_edge(instance, edge)
      edge_vector = canonical_edge_dir(edge)
      return if edge_vector.length < 1e-6
      align_axis(instance, instance.transformation.origin,
                 instance.transformation.yaxis, edge_vector.normalize)
    end

    # SketchUp 2017 can't parse "0 mm" but can parse "0mm"; also accepts plain
    # numeric strings stored in CONFIG (inches).
    def self.parse_length_safe(text)
      result = Sketchup.parse_length(text) rescue nil
      result = Sketchup.parse_length(text.delete(' ')) rescue nil if result.nil?
      result = text.to_f if result.nil? && text =~ /\A-?[\d.]+\z/
      result
    end

    # Persists the raw inches value so offsets survive unit changes.
    def self.format_and_persist_offset(value, config_key)
      OrienterExpress.user_settings(config_key => value.to_s) if CONFIG[:remember_offset]
      Sketchup.format_length(value)
    end

    # Per-axis: reads CONFIG[:<tool_prefix>_offset_<axis>], falling back to the
    # global default_offset_<axis>. axis is :x, :y or :z.
    def self.load_offset_axis_str(tool_prefix, axis)
      key = "#{tool_prefix}_offset_#{axis}".to_sym
      raw = CONFIG[key]
      raw = CONFIG["default_offset_#{axis}".to_sym] if raw.nil? || raw.to_s.empty?
      return Sketchup.format_length(0) if raw.nil? || raw.to_s.empty?
      return Sketchup.format_length(raw.to_f) if raw.to_s =~ /\A-?[\d.]+\z/
      raw.to_s
    end

    # Legacy helper kept so tools that still read a single offset can boot.
    # Defaults to the Z-axis value, which matches the pre-split semantics for
    # most placement tools (offset along the main orientation axis).
    def self.load_offset_str(config_key)
      prefix =
        case config_key.to_s
        when /\A(.+)_offset\z/ then Regexp.last_match(1).to_sym
        else :oevertex
        end
      load_offset_axis_str(prefix, :z)
    end

    def self.default_offset_str
      load_offset_axis_str(:_default, :z)
    end

    # In-memory store for the last roll per tool (degrees).
    def self.last_roll_store
      @last_roll_store ||= {}
    end

    def self.load_last_roll_deg(tool_key)
      cached = last_roll_store[tool_key]
      return cached if cached
      stored = CONFIG["#{tool_key}_roll".to_sym]
      return stored.to_f unless stored.nil?
      CONFIG[:default_roll].to_f
    end

    def self.set_last_roll(tool_key, deg)
      last_roll_store[tool_key] = deg
      OrienterExpress.user_settings("#{tool_key}_roll".to_sym => deg) if CONFIG[:remember_roll]
    end

    def self.resolved_pivot(tool_key)
      custom = CONFIG[:pivot_custom]
      (custom.is_a?(Hash) && custom[tool_key]) || 'center'
    end

    # pivot: :origin, :base, or :center.
    # scale_axis picks which face is the "base": :x → min-X, :y → min-Y, else → min-Z.
    def self.move_pivot_to(entity, point, pivot, scale_axis = nil)
      entity_ref = case pivot
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

    def self.face_centroid(face)
      verts = face.outer_loop.vertices
      n = verts.length.to_f
      x = verts.inject(0.0) { |s, v| s + v.position.x } / n
      y = verts.inject(0.0) { |s, v| s + v.position.y } / n
      z = verts.inject(0.0) { |s, v| s + v.position.z } / n
      Geom::Point3d.new(x, y, z)
    end

    # Two reliable strategies: sum of unit vectors from neighbors (for asymmetric
    # nodes), then average face normal (for symmetric nodes on a surface).
    def self.vertex_flow_direction(vertex, edges)
      dirs = []
      edges.each do |edge|
        other = (edge.start == vertex) ? edge.end.position : edge.start.position
        dir   = vertex.position - other
        next if dir.length < 1e-6
        dirs << dir.normalize
      end

      return nil if dirs.empty?

      sum = Geom::Vector3d.new(dirs.inject(0.0) { |s, v| s + v.x }, dirs.inject(0.0) { |s, v| s + v.y }, dirs.inject(0.0) { |s, v| s + v.z })
      return sum.normalize if sum.length > 1e-6

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

    # Strategy 3 (cross product of coplanar edges) gives a perpendicular of
    # arbitrary sign; a BFS pass from reliable vertices (strategies 1+2) fixes
    # candidates whose plane normal has a component along a reliable neighbour.
    # Unreached candidates keep their arbitrary sign.
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

      result = reliable.merge(candidates)
      diffuse_flow_directions(result, vertex_edges)
      inherit_endpoint_dirs(result, vertex_edges)
      result
    end

    # Averages neighbor directions into `vertex`'s outward sign convention.
    # Each neighbor's direction is reversed so its arrow points from the
    # neighbor toward `vertex`, matching how the intrinsic sum is computed
    # in vertex_flow_direction (vertex.position - other.position).
    def self.average_outward_dirs(vertex, edges, dirs)
      sx = sy = sz = 0.0
      count = 0
      edges.each do |edge|
        w = (edge.start == vertex) ? edge.end : edge.start
        next unless dirs.key?(w)
        d = dirs[w].reverse
        sx += d.x; sy += d.y; sz += d.z
        count += 1
      end
      return nil if count.zero?
      v = Geom::Vector3d.new(sx, sy, sz)
      return nil if v.length < 1e-6
      v.normalize
    end

    # Fills vertices with no direction by averaging their resolved neighbors'
    # directions (flipped to the vertex's outward sign convention). Iterates
    # until no new vertex gets a direction or max passes reached.
    def self.diffuse_flow_directions(dirs, vertex_edges, passes: 5)
      return dirs if dirs.empty? || vertex_edges.empty?

      passes.times do
        progress = false
        vertex_edges.each do |vertex, edges|
          next if dirs.key?(vertex)
          avg = average_outward_dirs(vertex, edges, dirs)
          if avg
            dirs[vertex] = avg
            progress = true
          end
        end
        break unless progress
      end

      dirs
    end

    # Endpoints (degree 1) get the tangent of their only edge from
    # vertex_flow_direction, which on curved chains breaks the radial
    # convention of interior vertices. Extrapolate: take the rotation that
    # maps the second neighbor's dir to the first neighbor's dir, then apply
    # the same rotation to the first neighbor's dir. On an arc this yields
    # the true radial at the endpoint. Isolated A-B pairs keep their
    # tangents; if there is no usable second vertex, inherit directly.
    def self.inherit_endpoint_dirs(dirs, vertex_edges)
      vertex_edges.each do |vertex, edges|
        next unless edges.length == 1
        neighbor       = (edges.first.start == vertex) ? edges.first.end : edges.first.start
        neighbor_edges = vertex_edges[neighbor]
        next unless neighbor_edges
        next if neighbor_edges.length == 1
        next unless dirs.key?(neighbor)

        second = nil
        neighbor_edges.each do |e|
          w = (e.start == neighbor) ? e.end : e.start
          next if w == vertex
          if dirs.key?(w)
            second = w
            break
          end
        end

        d1 = dirs[neighbor]
        if second
          d2    = dirs[second]
          axis  = d2.cross(d1)
          if axis.length > 1e-6
            angle = d2.angle_between(d1)
            rot   = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0), axis, angle)
            dirs[vertex] = d1.transform(rot)
          else
            dirs[vertex] = d1
          end
        else
          dirs[vertex] = d1
        end
      end
      dirs
    end

    ### MAIN TOOLS ### ------------------------------------------------------------

    class OEPlacementTool

      @active_instance = nil
      class << self
        attr_accessor :active_instance
      end

      def on_config_changed(changed)
        return unless changed.key?(:pivot_custom)
        key = debug_tool_name.to_sym
        new_ip = OrienterExpress.send(:resolved_pivot, key).to_sym
        new_ip = :center unless respond_to?(:valid_pivots) ?
                                  valid_pivots.include?(new_ip) :
                                  %i[center base origin].include?(new_ip)
        return if new_ip == @pivot
        @pivot = new_ip
        update_vcb
        apply
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
        tool_key       = self.class.config_prefix
        if CONFIG[:remember_offset]
          @offset_x      = OrienterExpress.send(:load_offset_axis_str, tool_key, :x)
          @offset_y      = OrienterExpress.send(:load_offset_axis_str, tool_key, :y)
          @offset_z      = OrienterExpress.send(:load_offset_axis_str, tool_key, :z)
          @offset_align  = OrienterExpress.send(:load_offset_axis_str, tool_key, :align)
          @offset_normal = OrienterExpress.send(:load_offset_axis_str, tool_key, :normal)
        else
          @offset_x      = OrienterExpress.send(:load_offset_axis_str, :_default, :x)
          @offset_y      = OrienterExpress.send(:load_offset_axis_str, :_default, :y)
          @offset_z      = OrienterExpress.send(:load_offset_axis_str, :_default, :z)
          @offset_align  = OrienterExpress.send(:load_offset_axis_str, :_default, :align)
          @offset_normal = OrienterExpress.send(:load_offset_axis_str, :_default, :normal)
        end
        @offset_axis    = :z
        @offset_frame   = (CONFIG[:offset_frame] || 'world').to_s.to_sym
        @offset_enabled = CONFIG[:offset_enabled] != false
        self.class.last_offset_str = @offset_z
        roll_deg       = CONFIG[:remember_roll] ? OrienterExpress.send(:load_last_roll_deg, tool_key) : CONFIG[:default_roll].to_f
        @roll_angle    = roll_deg.to_f.degrees
        @watcher = SelectionWatcher.new { on_external_selection_change }
        @model.selection.add_observer(@watcher)
        OEPlacementTool.active_instance = self
        rebuild_h_dir_map
        Dialogs.open_tool_panel if defined?(Dialogs) && Dialogs.respond_to?(:open_tool_panel)
        update_vcb
        UI.start_timer(0, false) { apply; sync_selection; notify_panel } if @entity_def
      end

      def deactivate(view)
        OEPlacementTool.active_instance = nil if OEPlacementTool.active_instance.equal?(self)
        @model.selection.remove_observer(@watcher) if @watcher
        @watcher           = nil
        @applied           = false
        @previous_entities = []
        @placement_map     = {}
        apply_panel_scroll_stop if respond_to?(:apply_panel_scroll_stop)
        on_deactivate
        Dialogs.push_tool_state(nil) if defined?(Dialogs) && Dialogs.respond_to?(:tool_panel_visible?) && Dialogs.tool_panel_visible?
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
          OrienterExpress.send(:set_last_roll, self.class.config_prefix, (@roll_angle * 180.0 / Math::PI) % 360.0)
          apply
          update_vcb
        elsif @offset_enabled
          store_offset_axis(@offset_axis || :z, stripped)
          update_vcb
          apply
        end
      end

      def onKeyDown(key, _repeat, flags, view)
        case key
        when 17 then @mod_ctrl  = true
        when 16 then @mod_shift = true
        when 18 then @alt_handled = false
        else
          @mod_ctrl  = flags & COPY_MODIFIER_MASK      != 0
          @mod_shift = flags & CONSTRAIN_MODIFIER_MASK != 0
        end
        update_cursor
        view.invalidate
        case key
        when 16
          handle_ins_key unless @lbutton_down || @mod_ctrl
        when 18
          handle_mode_key
          @alt_handled = true
        when 27
          if @applied
            @model.start_operation(cancel_op_name, true)
            @previous_entities.each { |e| e.erase! if e.valid? }
            @previous_entities = []
            @model.commit_operation
            @applied = false
          end
          @model.select_tool(nil)
        when 37
          cycle_offset_axis(-1) if @offset_enabled
        when 38
          toggle_offset_frame if @offset_enabled
        when 39
          # reserved for Phase B: roll axis cycle
        when 40
          # reserved for Phase B: roll frame toggle
        when 36
          @roll_angle = CONFIG[:default_roll].to_f.degrees
          @offset_x      = OrienterExpress.send(:load_offset_axis_str, :_default, :x)
          @offset_y      = OrienterExpress.send(:load_offset_axis_str, :_default, :y)
          @offset_z      = OrienterExpress.send(:load_offset_axis_str, :_default, :z)
          @offset_align  = OrienterExpress.send(:load_offset_axis_str, :_default, :align)
          @offset_normal = OrienterExpress.send(:load_offset_axis_str, :_default, :normal)
          self.class.last_offset_str = @offset_z
          update_vcb
          apply
        else
          handle_key(key)
        end
      end

      def onKeyUp(key, _repeat, flags, view)
        case key
        when 17 then @mod_ctrl  = false
        when 16 then @mod_shift = false
        when 18
          # Fallback in case key-down Alt was swallowed by the OS.
          handle_mode_key unless @alt_handled
          @alt_handled = false
        else
          @mod_ctrl  = flags & COPY_MODIFIER_MASK      != 0
          @mod_shift = flags & CONSTRAIN_MODIFIER_MASK != 0
        end
        update_cursor
        view.invalidate
      end

      private

      def on_deactivate; end
      def handle_key(_key); end
      def handle_axis_key; end
      def handle_ins_key; end
      def handle_mode_key; end
      def on_drag(_ctrl, _shift, _view, _x, _y); end

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
        root_edge = paths.find { |path| path.first.is_a?(Sketchup::Edge) && path.length == 1 }
        return root_edge.first if root_edge
        placed = paths.find { |path| @placement_map.key?(path.first) }
        return placed.first if placed
        ph.best_picked
      end

      def pick_geometry_from_entity(entity)
        case entity
        when Sketchup::Edge   then [entity]
        when Sketchup::Face   then entity.edges.to_a
        when Sketchup::Vertex then entity.edges.to_a
        end
      end

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
        apply
        sync_selection
      end

      def on_geometry_changed
        rebuild_h_dir_map
      end

      def scroll_roll(direction)
        step = [CONFIG[:roll_step].to_f, 1.0].max
        @roll_angle = (@roll_angle + direction * step.degrees) % 360.degrees
        @roll_angle = 0.0 if @roll_angle < 1e-9
        OrienterExpress.send(:set_last_roll, self.class.config_prefix, (@roll_angle * 180.0 / Math::PI) % 360.0)
        apply
        update_vcb
      end

      def cycle_offset_axis(dir)
        order = %i[x y z]
        idx   = order.index(@offset_axis || :z) || 2
        @offset_axis = order[(idx + dir.to_i) % 3]
        update_vcb
      end

      def toggle_offset_frame
        @offset_frame = @offset_frame == :local ? :world : :local
        OrienterExpress.user_settings(offset_frame: @offset_frame.to_s)
        update_vcb
        apply
      end

      def offset_vector(entity_copy, context = nil)
        dx = OrienterExpress.send(:parse_length_safe, @offset_x.to_s).to_f
        dy = OrienterExpress.send(:parse_length_safe, @offset_y.to_s).to_f
        dz = OrienterExpress.send(:parse_length_safe, @offset_z.to_s).to_f
        da = OrienterExpress.send(:parse_length_safe, @offset_align.to_s).to_f
        dn = OrienterExpress.send(:parse_length_safe, @offset_normal.to_s).to_f

        vx = dx; vy = dy; vz = dz

        if da.abs >= 1e-9 || dn.abs >= 1e-9
          edge  = context.is_a?(Sketchup::Edge) ? context : @placement_map[entity_copy]
          frame = edge_outward_frame(edge) if edge.is_a?(Sketchup::Edge)
          if frame
            _side, outward, fwd = frame
            vx += fwd.x * da + outward.x * dn
            vy += fwd.y * da + outward.y * dn
            vz += fwd.z * da + outward.z * dn
          else
            t  = entity_copy.transformation
            ax = t.xaxis; az = t.zaxis
            vx += ax.x * da + az.x * dn
            vy += ax.y * da + az.y * dn
            vz += ax.z * da + az.z * dn
          end
        end

        Geom::Vector3d.new(vx, vy, vz)
      end

      def apply_offset_vector(entity_copy, context = nil)
        return unless @offset_enabled
        v = offset_vector(entity_copy, context)
        return if v.length < 1e-9
        entity_copy.transformation = Geom::Transformation.translation(v) * entity_copy.transformation
      end

      # Edge-outward frame: Z = canonical edge direction, Y = face normal
      # projected perpendicular to Z (outward), X = Z × Y (tangent on face).
      # Falls back to world Z (then world X) for naked edges with no reliable
      # face normal, so offsets stay deterministic on wireframe-only selections.
      def edge_outward_frame(edge)
        fwd_raw = OrienterExpress.canonical_edge_dir(edge)
        return nil if fwd_raw.length < 1e-9
        fwd = fwd_raw.normalize

        outward = nil
        raw_n   = avg_face_normal_for_edge(edge)
        if raw_n && raw_n.length > 1e-9
          d = raw_n.dot(fwd)
          outward = raw_n - Geom::Vector3d.new(fwd.x * d, fwd.y * d, fwd.z * d)
          outward = nil if outward.length < 1e-9
        end
        unless outward
          up  = Geom::Vector3d.new(0, 0, 1)
          d   = up.dot(fwd)
          cand = up - Geom::Vector3d.new(fwd.x * d, fwd.y * d, fwd.z * d)
          if cand.length > 1e-9
            outward = cand
          else
            ax = Geom::Vector3d.new(1, 0, 0)
            d  = ax.dot(fwd)
            outward = ax - Geom::Vector3d.new(fwd.x * d, fwd.y * d, fwd.z * d)
          end
        end
        return nil if outward.nil? || outward.length < 1e-9
        outward = outward.normalize
        side    = fwd.cross(outward)
        return nil if side.length < 1e-9
        [side.normalize, outward, fwd]
      end

      # Sign resolver: rotation_mode decides the shape of the orientation, but
      # the "up/outward" perpendicular axis can still end up flipped relative
      # to the surface (e.g. pointing into a solid instead of away from it).
      # After orienting, check if the outward-candidate axis has a positive
      # projection onto the outward reference (face normal → naked-edge normal
      # → world +Z); if it's negative, rotate 180° around the primary axis.
      def ensure_outward_sign(entity_copy, edge)
        Debug.log(OrienterExpress, :ensure_outward_sign, "eid=#{OrienterExpress.edge_id(edge)} enter")
        t = entity_copy.transformation

        primary      = nil
        outward_axis = nil
        ref_override = nil

        # In :ground mode with :z scale_axis, pick the outward axis that
        # gives a consistent result across verticals AND horizontals:
        #  - Vertical-face edges (face normal horizontal): X = face outward
        #    (matches orient_x_ground's convention for vertical edges).
        #  - Top/bottom-face edges (face normal vertical): Y = world up
        #    (falls back to the generic logic).
        if defined?(@rotation_mode) && @rotation_mode == :ground && @scale_axis == :z
          fn = avg_face_normal_for_edge(edge)
          if fn && fn.z.abs < 0.5
            primary, outward_axis = t.zaxis, t.xaxis
            ref_override = fn
          end
        end

        if primary.nil?
          primary, outward_axis =
            case @scale_axis
            when :x then [t.xaxis, t.zaxis]
            when :y then [t.yaxis, t.zaxis]
            else         [t.zaxis, t.yaxis]
            end
        end

        return if primary.length < 1e-9

        ref = ref_override || outward_reference(edge, primary)
        return unless ref

        pn   = primary.normalize
        d    = ref.dot(pn)
        proj = ref - Geom::Vector3d.new(pn.x * d, pn.y * d, pn.z * d)
        return if proj.length < 1e-9

        # Tolerance guards the orthogonal case: when the outward_axis is
        # already aligned with the ref, the perpendicular component drifts
        # ±1e-15 with float noise and can flip edges at random.
        if outward_axis.dot(proj) < -1e-6
          entity_copy.transform!(
            Geom::Transformation.rotation(entity_copy.bounds.center, primary, Math::PI)
          )
          Debug.log(OrienterExpress, :ensure_outward_sign, "eid=#{OrienterExpress.edge_id(edge)} FLIPPED")
        else
          Debug.log(OrienterExpress, :ensure_outward_sign, "eid=#{OrienterExpress.edge_id(edge)} no-flip")
        end
      rescue => e
        Debug.log(OrienterExpress, :ensure_outward_sign, "eid=#{OrienterExpress.edge_id(edge)} ERROR: #{e.class}: #{e.message}")
        raise
      end

      # Mode-aware outward reference for ensure_outward_sign.
      # :normal → face normal (surface-aligned).
      # :ground → world +Z for non-vertical edges; horizontalized face-normal /
      #           connected-edge fallback for vertical edges (where +Z is ∥ primary).
      # :flow   → face normal (flow handles tangential alignment separately).
      def outward_reference(edge, primary)
        mode = defined?(@rotation_mode) ? @rotation_mode : :normal
        pn   = primary.length > 1e-9 ? primary.normalize : nil

        if mode == :ground
          if pn && pn.z.abs < 0.95
            return Geom::Vector3d.new(0, 0, 1)
          end
          # Vertical edges: match orient_x_ground's reference
          # (vertex-flow horizontalized) so ensure_outward_sign doesn't
          # counter-flip the geometry-intrinsic frame.
          ref = OrienterExpress.send(:horizontal_ref_for_vertical_edge, edge, @h_dir_map, @h_dom_dirs)
          return ref if ref && ref.length > 1e-9
          return Geom::Vector3d.new(1, 0, 0)
        end

        n = avg_face_normal_for_edge(edge)
        return n if n && n.length > 1e-9
        begin
          n = OrienterExpress.send(:naked_edge_surface_normal, edge, @h_dir_map, @z_sign_map)
          return n if n && n.length > 1e-9
        rescue
        end
        return Geom::Vector3d.new(0, 0, 1) if pn.nil? || pn.z.abs < 0.95
        Geom::Vector3d.new(1, 0, 0)
      end

      def on_external_selection_change
        return if @syncing
        new_geometry = collect_geometry_from_selection(@model.selection)
        return if new_geometry.to_set == @geometry.to_set
        old_set      = @geometry.to_set
        new_set      = new_geometry.to_set
        @geometry    = new_geometry
        unless @entity_def
          notify_panel
          return
        end
        @syncing = true
        on_selection_changed(new_set, old_set)
        sync_selection
      ensure
        @syncing = false
        notify_panel
      end

      def collect_geometry_from_selection(selection)
        (selection.grep(Sketchup::Edge) +
         selection.grep(Sketchup::Face).flat_map(&:edges)).uniq.select(&:valid?)
      end

      def on_selection_changed(_new_set, _old_set)
        apply
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
          notify_panel
          return
        end
        render_vcb
        notify_panel
      end

      def render_vcb; end

      public

      def notify_panel
        return unless defined?(Dialogs) && Dialogs.respond_to?(:tool_panel_visible?) && Dialogs.tool_panel_visible?
        Dialogs.push_tool_state(self)
      end

      PIVOT_LABEL_KEYS = {
        center: :pivot_center_short,
        base:   :pivot_base_short,
        origin: :pivot_origin_short
      }.freeze

      def panel_pivots
        list = respond_to?(:valid_pivots) ? valid_pivots : %i[base center origin]
        %i[base center origin].select { |p| list.include?(p) }
      end

      def panel_schema
        pivot_default =
          if self.class.respond_to?(:config_prefix)
            OrienterExpress.send(:resolved_pivot, self.class.config_prefix).to_s
          else
            'center'
          end
        schema = []
        if defined?(@rotation_mode) && !@rotation_mode.nil?
          schema << {
            'key' => 'rotation_mode', 'type' => 'select', 'resettable' => true,
            'label' => Lang.t(:html, :settings, :rotation_mode).to_s,
            'default' => (CONFIG[:rotation_mode] || 'ground').to_s,
            'options' => %i[ground flow normal].map { |m|
              { 'value' => m.to_s, 'label' => Lang.t(:html, :settings, "rotation_#{m}".to_sym).to_s }
            }
          }
        end
        schema << {
          'key' => 'pivot', 'type' => 'select', 'resettable' => true,
          'label' => Lang.t(:html, :settings, :pivot).to_s,
          'default' => pivot_default,
          'options' => panel_pivots.map { |p|
            { 'value' => p.to_s, 'label' => Lang.t(:html, :settings, PIVOT_LABEL_KEYS[p]).to_s }
          }
        }
        if instance_variable_defined?(:@scale_axis)
          schema << {
            'key' => 'scale_axis', 'type' => 'select', 'resettable' => true,
            'label' => Lang.t(:html, :settings, :axis).to_s,
            'default' => 'z',
            'options' => [
              { 'value' => 'x', 'label' => 'X' },
              { 'value' => 'y', 'label' => 'Y' },
              { 'value' => 'z', 'label' => 'Z' }
            ]
          }
        end
        unit_name = Dialogs.unit_info[:name]
        schema << {
          'key' => 'offset_enabled', 'type' => 'switch',
          'label' => "#{Lang.t(:html, :settings, :use_offset)} (#{unit_name})"
        }
        if @offset_enabled
          schema << {
            'key' => 'offset_frame', 'type' => 'select', 'resettable' => true,
            'group' => 'offset', 'group_first' => true,
            'label' => Lang.t(:html, :settings, :offset_frame).to_s,
            'default' => 'world',
            'options' => [
              { 'value' => 'world', 'label' => Lang.t(:html, :settings, :axes_world).to_s },
              { 'value' => 'local', 'label' => Lang.t(:html, :settings, :axes_local).to_s }
            ]
          }
          local_frame = @offset_frame == :local && instance_variable_defined?(:@scale_axis)
          fields =
            if local_frame
              [['align', :offset_alignment], ['normal', :offset_normal]]
            else
              [['x', :offset_x], ['y', :offset_y], ['z', :offset_z]]
            end
          fields.each_with_index do |(suffix, label_key), i|
            schema << {
              'key' => "offset_#{suffix}", 'type' => 'length',
              'scrollable' => true, 'resettable' => true,
              'group' => 'offset', 'group_last' => (i == fields.length - 1),
              'label' => Lang.t(:html, :settings, label_key).to_s
            }
          end
        end
        schema << { 'key' => 'roll', 'type' => 'number',
                    'scrollable' => true, 'resettable' => true,
                    'label' => Lang.t(:html, :settings, :default_roll).to_s.gsub(/<[^>]+>/, ''),
                    'step' => 1, 'min' => 0, 'max' => 359 }
        schema
      end

      def panel_state
        key = self.class.respond_to?(:config_prefix) ? self.class.config_prefix : nil
        return { 'tool' => nil } unless key

        deg = ((@roll_angle || 0.0) * 180.0 / Math::PI) % 360.0
        title_leaf = Lang.t(:commands, key, :label)

        values = {
          'pivot'          => (@pivot || :center).to_s,
          'offset_enabled' => @offset_enabled ? 'on' : 'off',
          'offset_frame'   => (@offset_frame || :world).to_s,
          'offset_x'       => offset_display_value(:x),
          'offset_y'       => offset_display_value(:y),
          'offset_z'       => offset_display_value(:z),
          'offset_align'   => offset_display_value(:align),
          'offset_normal'  => offset_display_value(:normal),
          'roll'           => deg.round(2)
        }
        values['rotation_mode'] = (@rotation_mode || :ground).to_s if defined?(@rotation_mode) && !@rotation_mode.nil?
        values['scale_axis'] = (@scale_axis || :z).to_s if instance_variable_defined?(:@scale_axis)

        {
          'tool'     => key.to_s,
          'title'    => title_leaf.to_s,
          'sample'   => panel_sample_name,
          'geometry' => panel_geometry_info,
          'placed'   => panel_placed_count,
          'schema'   => panel_schema,
          'values'   => values
        }
      rescue => e
        Debug.log(self.class, :panel_state, "#{e.class}: #{e.message}")
        Debug.log(self.class, :panel_state, e.backtrace.first(5).join(" | ")) if e.backtrace
        { 'tool' => nil }
      end

      def panel_sample_name
        return '' unless @entity_def && @entity_def.valid?
        name = @entity_def.name.to_s
        name.empty? ? '' : name
      end

      def panel_geometry_info
        items = (@geometry || []).select(&:valid?)
        return { 'kind' => nil, 'count' => 0 } if items.empty?
        kind = case items.first
               when Sketchup::Edge   then 'edge'
               when Sketchup::Face   then 'face'
               when Sketchup::Vertex then 'vertex'
               end
        { 'kind' => kind, 'count' => items.length }
      end

      def panel_placed_count
        return 0 unless defined?(@previous_entities) && @previous_entities
        @previous_entities.count { |e| e && e.valid? }
      end

      def apply_panel_change(key, value)
        case key
        when :rotation_mode
          return unless defined?(@rotation_mode)
          sym = value.to_s.to_sym
          return unless %i[ground flow normal].include?(sym)
          return if sym == @rotation_mode
          @rotation_mode = sym
          rebuild_flow_map  if @rotation_mode == :flow  && respond_to?(:rebuild_flow_map, true)
          rebuild_h_dir_map if respond_to?(:rebuild_h_dir_map, true)
          update_vcb
          apply
        when :pivot
          sym = value.to_s.to_sym
          return unless panel_pivots.include?(sym)
          return if sym == @pivot
          @pivot = sym
          custom = CONFIG[:pivot_custom].dup
          custom[self.class.config_prefix] = @pivot.to_s
          OrienterExpress.user_settings(pivot_custom: custom)
          update_vcb
          apply
        when :scale_axis
          return unless instance_variable_defined?(:@scale_axis)
          sym = value.to_s.to_sym
          return unless %i[x y z].include?(sym)
          return if sym == @scale_axis
          @scale_axis = sym
          update_vcb
          apply
        when :offset_enabled
          enabled = value == true || value.to_s == 'on' || value.to_s == 'true'
          return if enabled == @offset_enabled
          @offset_enabled = enabled
          OrienterExpress.user_settings(offset_enabled: enabled)
          update_vcb
          apply
        when :offset_frame
          sym = value.to_s.to_sym
          return unless %i[world local].include?(sym)
          return if sym == @offset_frame
          @offset_frame = sym
          OrienterExpress.user_settings(offset_frame: sym.to_s)
          update_vcb
          apply
        when :offset_x, :offset_y, :offset_z, :offset_align, :offset_normal
          text = value.to_s.strip
          return if text.empty?
          if text =~ /\A-?[\d.,]+\z/
            text = "#{text.tr(',', '.')}#{Dialogs.unit_info[:name]}"
          end
          axis = key.to_s.sub('offset_', '').to_sym
          store_offset_axis(axis, text)
          update_vcb
          apply
        when :roll
          deg = value.to_f % 360.0
          @roll_angle = deg * Math::PI / 180.0
          OrienterExpress.send(:set_last_roll, self.class.config_prefix, deg)
          apply
          update_vcb
        end
      end

      # Panel-scroll hold: Ruby owns the cadence via UI.start_timer so the
      # repeat rate is independent of JS setInterval jitter and per-apply
      # duration. JS just sends start/stop signals.
      PANEL_SCROLL_HOLD_DELAY = 0.35  # seconds before repeat kicks in
      PANEL_SCROLL_INTERVAL   = 0.04  # seconds between repeat ticks

      def apply_panel_scroll_start(key, dir)
        apply_panel_scroll_stop
        d = dir.to_i
        return if d.zero?
        @_scroll_key    = key
        @_scroll_dir    = d
        @_scroll_active = true
        do_panel_scroll_tick # immediate first step
        @_scroll_hold_timer = UI.start_timer(PANEL_SCROLL_HOLD_DELAY, false) do
          @_scroll_hold_timer = nil
          schedule_next_panel_scroll_tick
        end
      end

      def apply_panel_scroll_stop
        @_scroll_active = false
        if @_scroll_hold_timer
          UI.stop_timer(@_scroll_hold_timer) rescue nil
          @_scroll_hold_timer = nil
        end
        if @_scroll_repeat_timer
          UI.stop_timer(@_scroll_repeat_timer) rescue nil
          @_scroll_repeat_timer = nil
        end
        @_scroll_key = nil
        @_scroll_dir = nil
      end

      def do_panel_scroll_tick
        key = @_scroll_key
        d   = @_scroll_dir
        return if key.nil? || d.nil? || d.zero?
        case key
        when :offset_x, :offset_y, :offset_z, :offset_align, :offset_normal
          axis = key.to_s.sub('offset_', '').to_sym
          scroll_offset_axis(axis, d)
        when :roll       then scroll_roll(d)
        when :scale_axis then scroll_scale_axis(d)
        end
      end

      # Re-schedule the next tick at the end of the current one so variable
      # apply duration can't collide with a fixed-cadence timer.
      def schedule_next_panel_scroll_tick
        return unless @_scroll_active
        @_scroll_repeat_timer = UI.start_timer(PANEL_SCROLL_INTERVAL, false) do
          @_scroll_repeat_timer = nil
          if @_scroll_active
            do_panel_scroll_tick
            schedule_next_panel_scroll_tick
          end
        end
      end

      def scroll_scale_axis(dir)
        return unless instance_variable_defined?(:@scale_axis)
        order = %i[x y z]
        idx   = order.index(@scale_axis) || 2
        @scale_axis = order[(idx + dir.to_i) % 3]
        apply
        update_vcb
      end

      def store_offset_axis(axis, text)
        instance_variable_set("@offset_#{axis}", text)
        self.class.last_offset_str = text if axis == :z
        OrienterExpress.user_settings("#{self.class.config_prefix}_offset_#{axis}".to_sym => text) if CONFIG[:remember_offset]
      end

      # Convert stored length ("10cm", "1.5", etc.) into a unit-less numeric
      # string in the current model unit, for display in the tool panel.
      def offset_display_value(axis)
        stored = instance_variable_get("@offset_#{axis}").to_s
        return "0" if stored.empty?
        inches = OrienterExpress.send(:parse_length_safe, stored).to_f
        factor = Dialogs.unit_info[:factor].to_f
        value  = (inches * factor).round(4)
        value == value.to_i ? value.to_i.to_s : value.to_s
      end

      def scroll_offset_axis(axis, dir)
        step_str = CONFIG[:offset_step].to_s
        step     = OrienterExpress.send(:parse_length_safe, step_str).to_f
        return if step == 0
        current  = OrienterExpress.send(:parse_length_safe, instance_variable_get("@offset_#{axis}").to_s).to_f
        new_val  = current + (dir * step)
        store_offset_axis(axis, Sketchup.format_length(new_val))
        apply
        update_vcb
      end

      def apply_panel_reset(key)
        case key
        when :offset_x, :offset_y, :offset_z, :offset_align, :offset_normal
          axis = key.to_s.sub('offset_', '').to_sym
          zero = Sketchup.format_length(0)
          store_offset_axis(axis, zero)
          update_vcb
          apply
        when :roll
          @roll_angle = 0.0
          OrienterExpress.send(:set_last_roll, self.class.config_prefix, 0.0)
          apply
          update_vcb
        when :offset_frame
          return if @offset_frame == :world
          @offset_frame = :world
          OrienterExpress.user_settings(offset_frame: 'world')
          update_vcb
          apply
        when :scale_axis
          return unless instance_variable_defined?(:@scale_axis)
          return if @scale_axis == :z
          @scale_axis = :z
          update_vcb
          apply
        when :pivot
          default = OrienterExpress.send(:resolved_pivot, self.class.config_prefix).to_sym
          return if default == @pivot
          return unless panel_pivots.include?(default)
          @pivot = default
          custom = CONFIG[:pivot_custom].dup
          custom[self.class.config_prefix] = @pivot.to_s
          OrienterExpress.user_settings(pivot_custom: custom)
          update_vcb
          apply
        end
      end

      private

      def debug_tool_name; "unknown"; end

      def debug_state
        return unless Debug.enabled
        parts  = []
        parts << @rotation_mode.to_s          if defined?(@rotation_mode)
        parts << (@pivot || :center).to_s
        parts << (@scale_axis || :z).to_s.upcase
        deg = defined?(@roll_angle) ? ((@roll_angle * 180.0 / Math::PI) % 360.0).round(1) : 0.0
        parts << "#{deg}°"
        line = parts.join(" | ")
        return if line == @last_debug_state
        @last_debug_state = line
        Debug.log(self.class, :state, line)
      end

      def no_sample_hint;   ""; end
      def no_geometry_hint; ""; end

      def build_status(hint_str)
        pfx = no_geometry_hint
        pfx.empty? ? hint_str : "#{pfx}  |  #{hint_str}"
      end

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
        # Canonicalize sign: rotating by -θ around -v == +θ around v, so flipping
        # the axis keeps the visual roll direction consistent across edges.
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

      def vcb_offset_info
        oa          = (@offset_axis || :z)
        oa_label    = oa.to_s.upcase
        off_label   = Lang.t(:html, :settings, :off).to_s.upcase
        frame_key   = @offset_frame == :local ? :axes_local : :axes_world
        frame_label = @offset_enabled ? Lang.t(:html, :settings, frame_key).to_s : off_label
        current_off = @offset_enabled ? instance_variable_get("@offset_#{oa}").to_s : off_label
        current_off = Sketchup.format_length(0) if current_off.empty?
        [oa_label, frame_label, current_off]
      end

      # reference_vec must be the direction scale_axis was originally aligned
      # with (OESurfaceTool territory), so min.{axis} lands on the correct face.
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

      def move_base_to_surface(entity_copy, target, surface_normal)
        n   = surface_normal.normalize
        t   = entity_copy.transformation
        db  = entity_copy.definition.bounds
        # Oriented BB (world-space corners of definition BB), not an AABB.
        world_corners = 8.times.map { |i| t * db.corner(i) }
        dot_n = ->(pt) { pt.x * n.x + pt.y * n.y + pt.z * n.z }
        min_proj  = world_corners.map { |p| dot_n.call(p) }.min
        ctr_world = t * db.center
        base_pt   = ctr_world.offset(n, min_proj - dot_n.call(ctr_world))
        entity_copy.transform!(Geom::Transformation.translation(target - base_pt))
      end

      # Base mode uses world-space OBB projection so the result is correct at
      # all roll steps. Surface priority: face normal → naked_edge_surface_normal
      # → +Z (ground/flow only). Normal mode without a face normal, and every
      # other pivot, fall through to move_pivot_to.
      def place_with_pivot(entity_copy, target, edge_normal_vec = nil, edge = nil)
        if @pivot == :base
          surface_dir = edge_normal_vec ||
                        (edge && OrienterExpress.send(:naked_edge_surface_normal, edge, @h_dir_map, @z_sign_map)) ||
                        (@rotation_mode != :normal && Geom::Vector3d.new(0, 0, 1))
          if surface_dir
            move_base_to_surface(entity_copy, target, surface_dir)
          else
            OrienterExpress.send(:move_pivot_to, entity_copy, target, @pivot, @scale_axis)
          end
        else
          OrienterExpress.send(:move_pivot_to, entity_copy, target, @pivot, @scale_axis)
        end
      end

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
        apply
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

      # XY direction per vertex for ground-mode orientation of vertical edges.
      # Delegates to horizontal_flow_directions, which BFS-propagates reliable
      # directions to symmetric vertices where simple averaging would cancel.
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
        @h_dom_dirs = OrienterExpress.send(:dominant_horizontal_directions, @geometry, 3)
      end

    end

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

      def self.config_prefix
        :oevertex
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
        @pivot = OrienterExpress.send(:resolved_pivot, :oevertex).to_sym
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
          apply
        else
          rebuild_h_dir_map
          
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
        "Cancel Edge Vertex Placement"
      end

      def handle_key(key)
        case key
        when 9 then handle_axis_key
        end
      end

      def handle_axis_key
        @scale_axis  = { z: :x, x: :y, y: :z }[@scale_axis]
        @first_apply = true
        update_vcb
        apply
      end

      def handle_ins_key
        @pivot = { center: :base, base: :origin, origin: :center }[@pivot]
        custom = CONFIG[:pivot_custom].dup
        custom[:oevertex] = @pivot.to_s
        OrienterExpress.user_settings(pivot_custom: custom)
        update_vcb
        apply
      end

      def handle_mode_key
        @rotation_mode = { ground: :flow, flow: :normal, normal: :ground }[@rotation_mode]
        rebuild_flow_map   if @rotation_mode == :flow
        rebuild_h_dir_map
        update_vcb
        apply
      end

      def debug_tool_name;  "oevertex"; end
      def no_sample_hint;   Lang.commands.oevertex.no_sample_hint.to_s;   end
      def no_geometry_hint; Lang.commands.oevertex.no_geometry_hint.to_s; end

      def render_vcb
        mode_key   = { ground: :rotation_ground, flow: :rotation_flow, normal: :rotation_normal }[@rotation_mode]
        mode_label = Lang.t(:html, :settings, mode_key).to_s.upcase
        axis_label = @scale_axis.to_s.upcase
        ip_key     = { base: :pivot_base_short, center: :pivot_center_short, origin: :pivot_origin_short }[@pivot]
        ip_label   = Lang.t(:html, :settings, ip_key).to_s.upcase
        oa_label, frame_label, current_off = vcb_offset_info
        hint = format(Lang.commands.oevertex.vcb_hint.to_s,
                      mode: mode_label, axis: axis_label, ip: ip_label,
                      offset_axis: oa_label, frame: frame_label)
        Sketchup.set_status_text("#{Lang.commands.oevertex.offset_prompt} #{oa_label} (#{frame_label})", 1)
        Sketchup.set_status_text(current_off, 2)
        Sketchup.set_status_text(build_status(hint), 0)
        debug_state
      end

      def apply(*_)
        return unless @entity_def

        transparent = !@first_apply
        @model.start_operation("Orienter Express: Edge Vertex Placement", true, false, transparent)

        begin
          @previous_entities.each { |e| e.erase! if e.valid? }
          @previous_entities = []
          @placement_map     = {}

          @geometry.each { |edge| place_for_edge(edge) }

          @model.commit_operation
          @first_apply   = false
          @applied       = true
          @skipped_edges = []
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

      def apply_diff(added, removed, *_)
        return unless @entity_def
        @model.start_operation("Orienter Express: Edge Vertex Placement", true, false, true)
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
        edge_vec = OrienterExpress.canonical_edge_dir(edge)
        return if edge_vec.length < 1e-6
        edge_dir = edge_vec.normalize
        [edge.start.position, edge.end.position].each do |vertex_pos|
          entity_copy = OrienterExpress.create_entity_copy(@entity_def, @entity_t)
          t = entity_copy.transformation
          case @scale_axis
          when :x then OrienterExpress.send(:align_axis, entity_copy, t.origin, t.xaxis, edge_dir)
          when :y then OrienterExpress.send(:align_axis, entity_copy, t.origin, t.yaxis, edge_dir)
          else         OrienterExpress.send(:align_axis, entity_copy, t.origin, t.zaxis, edge_dir)
          end
          case @rotation_mode
          when :flow
            case @scale_axis
            when :x then OrienterExpress.send(:orient_to_flow_around, entity_copy, edge, @flow_map, entity_copy.transformation.xaxis, entity_copy.transformation.zaxis, @h_dir_map, @h_dom_dirs, @scale_axis)
            when :y then OrienterExpress.send(:orient_to_flow_around, entity_copy, edge, @flow_map, entity_copy.transformation.yaxis, entity_copy.transformation.zaxis, @h_dir_map, @h_dom_dirs, @scale_axis)
            else         OrienterExpress.send(:orient_to_flow, entity_copy, edge, @flow_map, @h_dir_map, @h_dom_dirs)
            end
          when :normal
            case @scale_axis
            when :x then OrienterExpress.send(:orient_to_face_normal_around, entity_copy, edge, entity_copy.transformation.xaxis, entity_copy.transformation.zaxis)
            when :y then OrienterExpress.send(:orient_to_face_normal_around, entity_copy, edge, entity_copy.transformation.yaxis, entity_copy.transformation.zaxis)
            else         OrienterExpress.send(:orient_to_face_normal, entity_copy, edge, @h_dir_map)
            end
          else # ground
            n = avg_face_normal_for_edge(edge)
            OrienterExpress.send(:orient_ground_to_normal, entity_copy, n, @scale_axis, @h_dom_dirs) if n
          end
          ensure_outward_sign(entity_copy, edge)
          apply_roll(entity_copy)
          OrienterExpress.send(:move_pivot_to, entity_copy, vertex_pos, @pivot, @scale_axis)
          apply_offset_vector(entity_copy, edge)
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

      def self.config_prefix
        :oecenter
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
        @pivot = OrienterExpress.send(:resolved_pivot, :oecenter).to_sym
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
          apply
        else
          rebuild_h_dir_map
          
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
        "Cancel Center Placement"
      end

      def handle_key(key)
        case key
        when 9 then handle_axis_key
        end
      end

      def handle_axis_key
        @scale_axis  = { z: :x, x: :y, y: :z }[@scale_axis]
        @first_apply = true
        update_vcb
        apply
      end

      def handle_ins_key
        @pivot = { center: :base, base: :origin, origin: :center }[@pivot]
        custom = CONFIG[:pivot_custom].dup
        custom[:oecenter] = @pivot.to_s
        OrienterExpress.user_settings(pivot_custom: custom)
        update_vcb
        apply
      end

      def handle_mode_key
        @rotation_mode = { ground: :flow, flow: :normal, normal: :ground }[@rotation_mode]
        rebuild_flow_map   if @rotation_mode == :flow
        rebuild_h_dir_map
        update_vcb
        apply
      end

      def debug_tool_name;  "oecenter"; end
      def no_sample_hint;   Lang.commands.oecenter.no_sample_hint.to_s;   end
      def no_geometry_hint; Lang.commands.oecenter.no_geometry_hint.to_s; end

      def render_vcb
        mode_key   = { ground: :rotation_ground, flow: :rotation_flow, normal: :rotation_normal }[@rotation_mode]
        mode_label = Lang.t(:html, :settings, mode_key).to_s.upcase
        axis_label = @scale_axis.to_s.upcase
        ip_key     = { base: :pivot_base_short, center: :pivot_center_short, origin: :pivot_origin_short }[@pivot]
        ip_label   = Lang.t(:html, :settings, ip_key).to_s.upcase
        oa_label, frame_label, current_off = vcb_offset_info
        hint = format(Lang.commands.oecenter.vcb_hint.to_s,
                      mode: mode_label, axis: axis_label, ip: ip_label,
                      offset_axis: oa_label, frame: frame_label)
        Sketchup.set_status_text("#{Lang.commands.oecenter.offset_prompt} #{oa_label} (#{frame_label})", 1)
        Sketchup.set_status_text(current_off, 2)
        Sketchup.set_status_text(build_status(hint), 0)
        debug_state
      end

      def apply(*_)
        return unless @entity_def

        transparent = !@first_apply
        @model.start_operation("Orienter Express: Center Placement", true, false, transparent)

        begin
          @previous_entities.each { |e| e.erase! if e.valid? }
          @previous_entities = []
          @placement_map     = {}

          @geometry.each { |edge| place_for_edge(edge) }

          @model.commit_operation
          @first_apply   = false
          @applied       = true
          @skipped_edges = []
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

      def apply_diff(added, removed, *_)
        return unless @entity_def
        @model.start_operation("Orienter Express: Center Placement", true, false, true)
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
        case @scale_axis
        when :x then OrienterExpress.orient_x_to_edge(entity_copy, edge)
        when :y then OrienterExpress.orient_y_to_edge(entity_copy, edge)
        else         OrienterExpress.orient_z(entity_copy, edge)
        end
        case @rotation_mode
        when :flow
          case @scale_axis
          when :x then OrienterExpress.send(:orient_to_flow_around, entity_copy, edge, @flow_map, entity_copy.transformation.xaxis, entity_copy.transformation.zaxis, @h_dir_map, @h_dom_dirs, @scale_axis)
          when :y then OrienterExpress.send(:orient_to_flow_around, entity_copy, edge, @flow_map, entity_copy.transformation.yaxis, entity_copy.transformation.zaxis, @h_dir_map, @h_dom_dirs, @scale_axis)
          else         OrienterExpress.send(:orient_to_flow, entity_copy, edge, @flow_map, @h_dir_map, @h_dom_dirs)
          end
        when :normal
          case @scale_axis
          when :x then OrienterExpress.send(:orient_to_face_normal_around, entity_copy, edge, entity_copy.transformation.xaxis, entity_copy.transformation.zaxis)
          when :y then OrienterExpress.send(:orient_to_face_normal_around, entity_copy, edge, entity_copy.transformation.yaxis, entity_copy.transformation.zaxis)
          else         OrienterExpress.send(:orient_to_face_normal, entity_copy, edge, @h_dir_map)
          end
        else # ground
          n = avg_face_normal_for_edge(edge)
          OrienterExpress.send(:orient_ground_to_normal, entity_copy, n, @scale_axis, @h_dom_dirs) if n
        end
        midpoint = Geom::Point3d.linear_combination(0.5, edge.start.position, 0.5, edge.end.position)
        ensure_outward_sign(entity_copy, edge)
        apply_roll(entity_copy)
        edge_normal = avg_face_normal_for_edge(edge)
        place_with_pivot(entity_copy, midpoint, edge_normal, edge)
        apply_offset_vector(entity_copy, edge)
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


    class OEAxisScaleTool < OEPlacementTool

      def self.cursor_id(variant = :default)
        @@cursor_ids ||= {}
        @@cursor_ids[variant] ||= begin
          ext  = Sketchup.platform == :platform_win ? 'svg' : 'pdf'
          filename = variant == :default ? "oe_axisscale_32" : "oe_axisscale_#{variant}_32"
          path = File.join(PATH_CURSORS, "#{filename}.#{ext}")
          UI.create_cursor(path, 5, 5)
        end
      end

      def self.config_prefix
        :oeaxisscale
      end

      def self.last_offset_str
        @@last_offset_str ||= OrienterExpress.send(:load_offset_str, :oeaxisscale_offset)
      end

      def self.last_offset_str=(val)
        @@last_offset_str = val
      end

      def initialize(edges, entity, flow_map, rotation_mode)
        super(edges, entity)
        @flow_map        = flow_map
        @rotation_mode   = rotation_mode
        @scale_axis      = :z
        ip = OrienterExpress.send(:resolved_pivot, :oeaxisscale).to_sym
        @pivot = [:center, :base].include?(ip) ? ip : :center
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
          apply
        else
          rebuild_h_dir_map
          
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
        "Cancel Z-Scaling"
      end

      def handle_key(key)
        case key
        when 9 then handle_axis_key
        end
      end

      def handle_axis_key
        @scale_axis  = { x: :y, y: :z, z: :x }[@scale_axis]
        @first_apply = true
        update_vcb
        apply
      end

      def handle_ins_key
        @pivot = @pivot == :center ? :base : :center
        custom = CONFIG[:pivot_custom].dup
        custom[:oeaxisscale] = @pivot.to_s
        OrienterExpress.user_settings(pivot_custom: custom)
        update_vcb
        apply
      end

      def handle_mode_key
        @rotation_mode = { ground: :flow, flow: :normal, normal: :ground }[@rotation_mode]
        rebuild_flow_map   if @rotation_mode == :flow
        rebuild_h_dir_map
        update_vcb
        apply
      end

      def debug_tool_name;        "oeaxisscale"; end
      def valid_pivots; %i[base center]; end
      def no_sample_hint;   Lang.commands.oeaxisscale.no_sample_hint.to_s;   end
      def no_geometry_hint; Lang.commands.oeaxisscale.no_geometry_hint.to_s; end

      def render_vcb
        mode_key   = { ground: :rotation_ground, flow: :rotation_flow, normal: :rotation_normal }[@rotation_mode]
        mode_label = Lang.t(:html, :settings, mode_key).to_s.upcase
        axis_label = @scale_axis.to_s.upcase
        ip_key     = @pivot == :base ? :pivot_base_short : :pivot_center_short
        ip_label   = Lang.t(:html, :settings, ip_key).to_s.upcase
        oa_label, frame_label, current_off = vcb_offset_info
        hint = format(Lang.commands.oeaxisscale.vcb_hint.to_s,
                      mode: mode_label, axis: axis_label, ip: ip_label,
                      offset_axis: oa_label, frame: frame_label)
        Sketchup.set_status_text("#{Lang.commands.oeaxisscale.offset_prompt} #{oa_label} (#{frame_label})", 1)
        Sketchup.set_status_text(current_off, 2)
        Sketchup.set_status_text(build_status(hint), 0)
        debug_state
      end

      def apply(*_)
        return unless @entity_def

        transparent = !@first_apply
        @model.start_operation("Orienter Express: Z-Scaling", true, false, transparent)

        begin
          @previous_entities.each { |e| e.erase! if e.valid? }
          @previous_entities = []
          @placement_map     = {}

          @geometry.each { |edge| place_for_edge(edge) }

          @model.commit_operation
          @first_apply   = false
          @applied       = true
          @skipped_edges = []
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

      def apply_diff(added, removed, *_)
        return unless @entity_def
        @model.start_operation("Orienter Express: Z-Scaling", true, false, true)
        begin
          removed.each do |edge|
            @skipped_edges.delete(edge) if @skipped_edges
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
        case @scale_axis
        when :x
          OrienterExpress.x_scale(entity_copy, edge, edge.length)
          OrienterExpress.orient_x_to_edge(entity_copy, edge)
        when :y
          OrienterExpress.y_scale(entity_copy, edge, edge.length)
          OrienterExpress.orient_y_to_edge(entity_copy, edge)
        else
          OrienterExpress.z_scale(entity_copy, edge, edge.length)
          OrienterExpress.orient_z(entity_copy, edge)
        end
        case @rotation_mode
        when :flow
          case @scale_axis
          when :x then OrienterExpress.send(:orient_to_flow_around, entity_copy, edge, @flow_map, entity_copy.transformation.xaxis, entity_copy.transformation.zaxis, @h_dir_map, @h_dom_dirs, @scale_axis)
          when :y then OrienterExpress.send(:orient_to_flow_around, entity_copy, edge, @flow_map, entity_copy.transformation.yaxis, entity_copy.transformation.zaxis, @h_dir_map, @h_dom_dirs, @scale_axis)
          else         OrienterExpress.send(:orient_to_flow, entity_copy, edge, @flow_map, @h_dir_map, @h_dom_dirs)
          end
        when :normal
          case @scale_axis
          when :x then OrienterExpress.send(:orient_to_face_normal_around, entity_copy, edge, entity_copy.transformation.xaxis, entity_copy.transformation.zaxis)
          when :y then OrienterExpress.send(:orient_to_face_normal_around, entity_copy, edge, entity_copy.transformation.yaxis, entity_copy.transformation.zaxis)
          else         OrienterExpress.send(:orient_to_face_normal, entity_copy, edge, @h_dir_map)
          end
        else # ground
          case @scale_axis
          when :x then OrienterExpress.send(:orient_z_ground, entity_copy, edge, @h_dir_map, @h_dom_dirs)
          when :y then OrienterExpress.send(:orient_y_ground, entity_copy, edge, @h_dir_map, @h_dom_dirs)
          else         OrienterExpress.send(:orient_x_ground, entity_copy, edge, @h_dir_map, @h_dom_dirs)
          end
        end
        midpoint = Geom::Point3d.linear_combination(0.5, edge.start.position, 0.5, edge.end.position)
        ensure_outward_sign(entity_copy, edge)
        apply_roll(entity_copy)
        if @pivot == :base
          OrienterExpress.send(:move_pivot_to, entity_copy, midpoint, :center, @scale_axis)
          # Project the "up" reference onto the cross-section plane (⊥ scale axis),
          # so base lands on the correct side of the surface regardless of mode.
          # Face normal first; fall back to naked_edge_surface_normal, then world +Z.
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
          # up_perp degenerates to zero on vertical edges (no defined "down" in
          # cross-section) — skip the base adjustment there.
          move_base_to_surface(entity_copy, midpoint, up_perp) if up_perp.length > 1e-6
        else
          OrienterExpress.send(:move_pivot_to, entity_copy, midpoint, @pivot, @scale_axis)
        end
        apply_offset_vector(entity_copy, edge)
        @previous_entities << entity_copy
        @placement_map[entity_copy] = edge
      end
    end

    def self.oeaxisscale
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
        OEAxisScaleTool.new(edges, entity, flow_map, rotation_mode)
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

      def self.config_prefix
        :oeuscale
      end

      def self.last_offset_str
        @@last_offset_str ||= OrienterExpress.send(:load_offset_str, :oeuscale_offset)
      end

      def self.last_offset_str=(val)
        @@last_offset_str = val
      end

      def initialize(edges, entity, flow_map, rotation_mode)
        super(edges, entity)
        @flow_map        = flow_map
        @rotation_mode   = rotation_mode
        @scale_axis      = :z
        ip = OrienterExpress.send(:resolved_pivot, :oeuscale).to_sym
        @pivot = [:center, :base].include?(ip) ? ip : :center
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
          apply
        else
          rebuild_h_dir_map
          
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

      def handle_key(key)
        case key
        when 9 then handle_axis_key
        end
      end

      def handle_axis_key
        @scale_axis  = { x: :y, y: :z, z: :x }[@scale_axis]
        @first_apply = true
        update_vcb
        apply
      end

      def handle_ins_key
        @pivot = @pivot == :center ? :base : :center
        custom = CONFIG[:pivot_custom].dup
        custom[:oeuscale] = @pivot.to_s
        OrienterExpress.user_settings(pivot_custom: custom)
        update_vcb
        apply
      end

      def handle_mode_key
        @rotation_mode = { ground: :flow, flow: :normal, normal: :ground }[@rotation_mode]
        rebuild_flow_map   if @rotation_mode == :flow
        rebuild_h_dir_map
        update_vcb
        apply
      end

      def debug_tool_name;        "oeuscale"; end
      def valid_pivots; %i[base center]; end
      def no_sample_hint;   Lang.commands.oeuscale.no_sample_hint.to_s;   end
      def no_geometry_hint; Lang.commands.oeuscale.no_geometry_hint.to_s; end

      def render_vcb
        mode_key   = { ground: :rotation_ground, flow: :rotation_flow, normal: :rotation_normal }[@rotation_mode]
        mode_label = Lang.t(:html, :settings, mode_key).to_s.upcase
        axis_label = @scale_axis.to_s.upcase
        ip_key     = @pivot == :base ? :pivot_base_short : :pivot_center_short
        ip_label   = Lang.t(:html, :settings, ip_key).to_s.upcase
        oa_label, frame_label, current_off = vcb_offset_info
        hint = format(Lang.commands.oeuscale.vcb_hint.to_s,
                      mode: mode_label, axis: axis_label, ip: ip_label,
                      offset_axis: oa_label, frame: frame_label)
        Sketchup.set_status_text("#{Lang.commands.oeuscale.offset_prompt} #{oa_label} (#{frame_label})", 1)
        Sketchup.set_status_text(current_off, 2)
        Sketchup.set_status_text(build_status(hint), 0)
        debug_state
      end

      def apply(*_)
        return unless @entity_def

        transparent = !@first_apply
        @model.start_operation("Orienter Express: Uniform Scaling", true, false, transparent)

        begin
          @previous_entities.each { |e| e.erase! if e.valid? }
          @previous_entities = []
          @placement_map     = {}

          @geometry.each { |edge| place_for_edge(edge) }

          @model.commit_operation
          @first_apply   = false
          @applied       = true
          @skipped_edges = []
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

      def apply_diff(added, removed, *_)
        return unless @entity_def
        @model.start_operation("Orienter Express: Uniform Scaling", true, false, true)
        begin
          removed.each do |edge|
            @skipped_edges.delete(edge) if @skipped_edges
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
        OrienterExpress.uniform_scale(entity_copy, edge, @scale_axis, edge.length)
        case @scale_axis
        when :x then OrienterExpress.orient_x_to_edge(entity_copy, edge)
        when :y then OrienterExpress.orient_y_to_edge(entity_copy, edge)
        else         OrienterExpress.orient_z(entity_copy, edge)
        end
        case @rotation_mode
        when :flow
          case @scale_axis
          when :x then OrienterExpress.send(:orient_to_flow_around, entity_copy, edge, @flow_map, entity_copy.transformation.xaxis, entity_copy.transformation.zaxis, @h_dir_map, @h_dom_dirs, @scale_axis)
          when :y then OrienterExpress.send(:orient_to_flow_around, entity_copy, edge, @flow_map, entity_copy.transformation.yaxis, entity_copy.transformation.zaxis, @h_dir_map, @h_dom_dirs, @scale_axis)
          else         OrienterExpress.send(:orient_to_flow, entity_copy, edge, @flow_map, @h_dir_map, @h_dom_dirs)
          end
        when :normal
          case @scale_axis
          when :x then OrienterExpress.send(:orient_to_face_normal_around, entity_copy, edge, entity_copy.transformation.xaxis, entity_copy.transformation.zaxis)
          when :y then OrienterExpress.send(:orient_to_face_normal_around, entity_copy, edge, entity_copy.transformation.yaxis, entity_copy.transformation.zaxis)
          else         OrienterExpress.send(:orient_to_face_normal, entity_copy, edge, @h_dir_map)
          end
        else # ground
          case @scale_axis
          when :x then OrienterExpress.send(:orient_z_ground, entity_copy, edge, @h_dir_map, @h_dom_dirs)
          when :y then OrienterExpress.send(:orient_y_ground, entity_copy, edge, @h_dir_map, @h_dom_dirs)
          else         OrienterExpress.send(:orient_x_ground, entity_copy, edge, @h_dir_map, @h_dom_dirs)
          end
        end
        midpoint = Geom::Point3d.linear_combination(0.5, edge.start.position, 0.5, edge.end.position)
        ensure_outward_sign(entity_copy, edge)
        apply_roll(entity_copy)
        if @pivot == :base
          OrienterExpress.send(:move_pivot_to, entity_copy, midpoint, :center, @scale_axis)
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
          move_base_to_surface(entity_copy, midpoint, up_perp) if up_perp.length > 1e-6
        else
          OrienterExpress.send(:move_pivot_to, entity_copy, midpoint, @pivot, @scale_axis)
        end
        apply_offset_vector(entity_copy, edge)
        @previous_entities << entity_copy
        @placement_map[entity_copy] = edge
      end
    end

    def self.oeuscale
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
        OEUScaleTool.new(edges, entity, flow_map, rotation_mode)
      )
    end

    class OEFlowTool < OEPlacementTool

      def self.config_prefix
        :oeflow
      end

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
        @pivot = OrienterExpress.send(:resolved_pivot, :oeflow).to_sym
      end

      private

      def on_drag(ctrl, shift, view, x, y)
        return unless @lbutton_down && @drag_mode && ctrl
        entity = pick_entity(view, x, y)
        picked = pick_geometry_from_entity(entity)
        modify_geometry(@drag_mode, picked) if picked
      end

      def on_selection_changed(_new_set, _old_set)
        apply
      end

      # Flow tool deliberately does not add full_faces to the selection.
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
        when 9 then handle_axis_key
        end
      end

      def handle_axis_key
        @scale_axis  = { z: :x, x: :y, y: :z }[@scale_axis]
        @first_apply = true
        update_vcb
        apply
      end

      def handle_ins_key
        @pivot = { center: :base, base: :origin, origin: :center }[@pivot]
        custom = CONFIG[:pivot_custom].dup
        custom[:oeflow] = @pivot.to_s
        OrienterExpress.user_settings(pivot_custom: custom)
        update_vcb
        apply
      end

      def handle_mode_key
        @rotation_mode = { ground: :flow, flow: :normal, normal: :ground }[@rotation_mode]
        update_vcb
        apply
      end

      def debug_tool_name;  "oeflow"; end
      def no_sample_hint;   Lang.commands.oeflow.no_sample_hint.to_s;   end
      def no_geometry_hint; Lang.commands.oeflow.no_geometry_hint.to_s; end

      def render_vcb
        mode_key   = { ground: :rotation_ground, flow: :rotation_flow, normal: :rotation_normal }[@rotation_mode]
        mode_label = Lang.t(:html, :settings, mode_key).to_s.upcase
        axis_label = @scale_axis.to_s.upcase
        ip_key     = { base: :pivot_base_short, center: :pivot_center_short, origin: :pivot_origin_short }[@pivot]
        ip_label   = Lang.t(:html, :settings, ip_key).to_s.upcase
        oa_label, frame_label, current_off = vcb_offset_info
        hint = format(Lang.commands.oeflow.vcb_hint.to_s,
                      mode: mode_label, axis: axis_label, ip: ip_label,
                      offset_axis: oa_label, frame: frame_label)
        Sketchup.set_status_text("#{Lang.commands.oeflow.offset_prompt} #{oa_label} (#{frame_label})", 1)
        Sketchup.set_status_text(current_off, 2)
        Sketchup.set_status_text(build_status(hint), 0)
        debug_state
      end

      def apply(*_)
        return unless @entity_def

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
            target      = vertex.position
            entity_copy = OrienterExpress.create_entity_copy(@entity_def, @entity_t)
            t           = entity_copy.transformation

            case @scale_axis
            when :x
              OrienterExpress.send(:align_axis, entity_copy, t.origin, t.xaxis, direction)
            when :y
              OrienterExpress.send(:align_axis, entity_copy, t.origin, t.yaxis, direction)
            else
              OrienterExpress.send(:align_axis, entity_copy, t.origin, t.zaxis, direction)
            end

            rep_edge = vertex_edges[vertex] ? vertex_edges[vertex].first : nil

            case @rotation_mode
            when :flow
              if rep_edge
                case @scale_axis
                when :x
                  OrienterExpress.send(:orient_to_flow_around, entity_copy, rep_edge, flow_map,
                                       entity_copy.transformation.xaxis,
                                       entity_copy.transformation.zaxis,
                                       @h_dir_map, @h_dom_dirs, @scale_axis)
                when :y
                  OrienterExpress.send(:orient_to_flow_around, entity_copy, rep_edge, flow_map,
                                       entity_copy.transformation.yaxis,
                                       entity_copy.transformation.zaxis,
                                       @h_dir_map, @h_dom_dirs, @scale_axis)
                else
                  OrienterExpress.send(:orient_to_flow, entity_copy, rep_edge, flow_map,
                                       @h_dir_map, @h_dom_dirs)
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
              t2 = entity_copy.transformation
              rot_axis, target_axis = case @scale_axis
                                      when :x then [t2.xaxis, t2.yaxis]
                                      when :y then [t2.yaxis, t2.zaxis]
                                      else         [t2.zaxis, t2.xaxis]
                                      end
              OrienterExpress.send(:orient_ground_around, entity_copy, rot_axis, target_axis)
            end

            apply_roll(entity_copy)
            OrienterExpress.send(:move_pivot_to, entity_copy, target, @pivot, @scale_axis)
            apply_offset_vector(entity_copy, rep_edge)
            @previous_entities << entity_copy
            @placement_map[entity_copy] = vertex
          end

          @model.commit_operation
          @first_apply = false
          @applied     = true
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

    class OESurfaceTool < OEPlacementTool

      def self.config_prefix
        :oesurface
      end

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
        @pivot = OrienterExpress.send(:resolved_pivot, :oesurface).to_sym
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
          apply
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

      def pick_geometry_from_entity(entity)
        case entity
        when Sketchup::Face
          soft_group_for(entity)
        when Sketchup::Edge
          entity.faces.flat_map { |f| soft_group_for(f) }.uniq
        end
      end

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
        ph    = view.pick_helper
        count = ph.do_pick(x, y, 16)
        paths = count.times.map { |i| ph.path_at(i) }
        root_geom = paths.find { |path|
          path.length == 1 && (path.first.is_a?(Sketchup::Face) || path.first.is_a?(Sketchup::Edge))
        }
        raw = if root_geom
                root_geom.first
              else
                placed = paths.find { |path| @placement_map.key?(path.first) }
                placed ? placed.first : ph.best_picked
              end
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

      # Full re-apply: group boundaries depend on the full set of selected faces.
      def on_selection_changed(_new_set, _old_set)
        apply
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
        when 9 then handle_axis_key
        end
      end

      def handle_axis_key
        @scale_axis  = { z: :x, x: :y, y: :z }[@scale_axis]
        @first_apply = true
        update_vcb
        apply
      end

      def handle_ins_key
        @pivot = { center: :base, base: :origin, origin: :center }[@pivot]
        custom = CONFIG[:pivot_custom].dup
        custom[:oesurface] = @pivot.to_s
        OrienterExpress.user_settings(pivot_custom: custom)
        update_vcb
        apply
      end

      def handle_mode_key
        @axis_idx = (@axis_idx + 1) % 2
        update_vcb
        apply
      end

      def debug_tool_name;  "oesurface"; end
      def no_sample_hint;   Lang.commands.oesurface.no_sample_hint.to_s;   end
      def no_geometry_hint; Lang.commands.oesurface.no_geometry_hint.to_s; end

      def render_vcb
        scale_label  = @scale_axis.to_s.upcase
        orient_label = [
          Lang.commands.oesurface.axis_parallel,
          Lang.commands.oesurface.axis_ground
        ][@axis_idx].to_s.upcase
        ip_key   = { base: :pivot_base_short, center: :pivot_center_short, origin: :pivot_origin_short }[@pivot]
        ip_label = Lang.t(:html, :settings, ip_key).to_s.upcase
        oa_label, frame_label, current_off = vcb_offset_info
        hint = format(Lang.commands.oesurface.vcb_hint.to_s,
                      axis: scale_label, orient: orient_label, ip: ip_label,
                      offset_axis: oa_label, frame: frame_label)
        Sketchup.set_status_text("#{Lang.commands.oesurface.offset_prompt} #{oa_label} (#{frame_label})", 1)
        Sketchup.set_status_text(current_off, 2)
        Sketchup.set_status_text(build_status(hint), 0)
        debug_state
      end

      def apply_diff(*_)
        apply
      end

      def apply(*_)
        return unless @entity_def

        transparent = !@first_apply
        @model.start_operation("Orienter Express: Surface Placement", true, false, transparent)

        begin
          @previous_entities.each { |e| e.erase! if e.valid? }
          @previous_entities = []
          @placement_map     = {}

          if @smooth_groups
            compute_groups.each { |group| place_for_group(group) }
          else
            @geometry.select(&:valid?).each { |face| place_for_group([face]) }
          end

          @model.commit_operation
          @first_apply = false
          @applied     = true
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

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

      def place_for_group(group_faces)
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

        # Area-weighted centroid is correct for flat groups but may fall inside
        # the geometry on curved surfaces — below we project it onto the nearest
        # face plane along avg_normal so placement lands on the surface.
        avg_centroid = Geom::Point3d.new(cx / total_area, cy / total_area, cz / total_area)

        n = avg_normal.normalize
        contact   = avg_centroid
        min_abs_t = Float::INFINITY

        valid.each do |face|
          denom = face.normal.dot(n)
          next if denom.abs < 1e-6

          fc    = OrienterExpress.send(:face_centroid, face)
          ray_t = face.normal.dot(fc - avg_centroid) / denom
          next unless ray_t.abs < min_abs_t

          min_abs_t = ray_t.abs
          contact   = avg_centroid.offset(n, ray_t)
        end

        target = contact

        entity_copy = OrienterExpress.create_entity_copy(@entity_def, @entity_t)
        t           = entity_copy.transformation

        case @scale_axis
        when :x then OrienterExpress.align_axis(entity_copy, t.origin, t.xaxis, avg_normal)
        when :y then OrienterExpress.align_axis(entity_copy, t.origin, t.yaxis, avg_normal)
        else         OrienterExpress.align_axis(entity_copy, t.origin, t.zaxis, avg_normal)
        end

        primary = valid.max_by(&:area)
        if @axis_idx == 1
          case @scale_axis
          when :x then OrienterExpress.send(:orient_z_ground, entity_copy)
          when :y then OrienterExpress.send(:orient_y_ground, entity_copy)
          else         OrienterExpress.orient_x(entity_copy)
          end
        else
          OrienterExpress.orient_to_face_edge(entity_copy, primary, 0, @scale_axis)
        end

        apply_roll(entity_copy)
        base_axis = @pivot == :base ? axis_most_aligned_to(entity_copy, avg_normal) : @scale_axis
        OrienterExpress.send(:move_pivot_to, entity_copy, target, @pivot, base_axis)
        apply_offset_vector(entity_copy)

        @previous_entities << entity_copy
        @placement_map[entity_copy] = primary
      rescue
        # Skip degenerate groups (cancelled normals, zero-length vectors, etc.)
        # so the rest of the placement continues.
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
        custom = CONFIG[:pivot_custom]
        @pivot = (custom.is_a?(Hash) && custom[:oereset] ? custom[:oereset].to_sym : :base)
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
        when 27
          @model.select_tool(nil)
        when 9
          @pivot = { center: :origin, origin: :base, base: :center }[@pivot]
          custom = CONFIG[:pivot_custom] || {}
          OrienterExpress.user_settings(pivot_custom: custom.merge(oereset: @pivot.to_s))
          update_vcb
        end
      end

      private

      def pivot_for(entity, original_t)
        case @pivot
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
        ip_key = { base: :pivot_base_short, center: :pivot_center_short, origin: :pivot_origin_short }[@pivot]
        ip     = Lang.t(:html, :settings, ip_key).to_s.upcase
        desc   = Lang.commands.oereset.no_geometry_hint
        hint   = format(Lang.commands.oereset.vcb_hint.to_s, ip: ip.to_s)
        Sketchup.set_status_text("#{desc}  |  #{hint}", 0)
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

    def self.convex_hull_3d(pts)
      convex_hull_3d_with_faces(pts).first
    end

    # Returns [hull_pts, face_triples]; face triples index into hull_pts.
    def self.convex_hull_3d_with_faces(pts)
      return [pts, []] if pts.size <= 3

      eps = 1e-8

      # Positive signed distance = p lies on the outward-normal side of the face.
      sd = lambda do |ia, ib, ic, p|
        a=pts[ia]; b=pts[ib]; c=pts[ic]
        ux=b.x-a.x; uy=b.y-a.y; uz=b.z-a.z
        vx=c.x-a.x; vy=c.y-a.y; vz=c.z-a.z
        nx=uy*vz-uz*vy; ny=uz*vx-ux*vz; nz=ux*vy-uy*vx
        nx*(p.x-a.x) + ny*(p.y-a.y) + nz*(p.z-a.z)
      end

      ext = [:x,:y,:z].flat_map { |ax|
        [pts.each_with_index.min_by{|p,_| p.send(ax)}[1],
         pts.each_with_index.max_by{|p,_| p.send(ax)}[1]]
      }.uniq

      # Seed tetrahedron: most distant pair, farthest from that line, farthest from plane.
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

      # Tetrahedron centroid lives inside the final hull — use as inside reference.
      ctr = Geom::Point3d.new(
        (pts[i0].x+pts[i1].x+pts[i2].x+pts[i3].x)/4.0,
        (pts[i0].y+pts[i1].y+pts[i2].y+pts[i3].y)/4.0,
        (pts[i0].z+pts[i1].z+pts[i2].z+pts[i3].z)/4.0)

      # Orient face [a,b,c] so ctr is on the inside (negative signed distance).
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

        # Horizon: edges [a,b] on visible faces whose reverse [b,a] isn't visible.
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

    # O'Rourke face-flush heuristic: at the min-volume optimum at least one BB
    # face is flush with a hull face, so it's enough to try each hull normal as
    # +Z and solve the 2D min-area rectangle in XY. Returns [r00..r22, vol].
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

        # Calipers only need the 2D hull — extremes of a set coincide with its hull's.
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

    # Must run before any alignment: extracting r_reset and collecting
    # definition-space vertices both require the instance to be scale-free.
    def self.bake_scale(instance)
      t  = instance.transformation
      a  = t.to_a
      sx = Math.sqrt(a[0]**2 + a[1]**2 + a[2]**2)
      sy = Math.sqrt(a[4]**2 + a[5]**2 + a[6]**2)
      sz = Math.sqrt(a[8]**2 + a[9]**2 + a[10]**2)
      return if (sx - sy).abs < 1e-6 && (sx - sz).abs < 1e-6 && (sy - sz).abs < 1e-6

      r_scale     = Geom::Transformation.scaling(sx, sy, sz)
      r_scale_inv = Geom::Transformation.scaling(1.0/sx, 1.0/sy, 1.0/sz)

      instance.definition.entities.transform_entities(r_scale, instance.definition.entities.to_a)
      instance.definition.instances.each do |inst|
        inst.transformation = inst.transformation * r_scale_inv
      end
      Debug.log(self, :align_pca, "scale baked: (#{sx.round(4)}, #{sy.round(4)}, #{sz.round(4)})")
    end

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

    # Area-weighted sum of face.normal across a definition's top-level faces.
    # Unlike planar_normal's u×v (sign determined by vertex ordering), this is
    # signed by each face's front side, so the 2D auto path can use it to pick
    # the "outward" orientation consistent with the user's face.
    def self.signed_face_normal_for_def(definition)
      sum_x = sum_y = sum_z = 0.0
      total_area = 0.0
      definition.entities.each do |e|
        next unless e.is_a?(Sketchup::Face)
        a = e.area
        next if a < 1e-12
        n = e.normal
        sum_x += n.x * a
        sum_y += n.y * a
        sum_z += n.z * a
        total_area += a
      end
      return nil if total_area < 1e-12
      len = Math.sqrt(sum_x * sum_x + sum_y * sum_y + sum_z * sum_z)
      return nil if len < 1e-6
      [sum_x / len, sum_y / len, sum_z / len]
    end

    # Unit plane normal if pts are coplanar (max deviation < 1e-4 * span), else nil.
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

    # Picks the best of the 24 proper rotations of the cube (6 perms × 4 sign
    # combos). With z_pre/x_pre: primary score is alignment with those pre-axes
    # (×100), extent ordering is a tiebreaker. Without: extent ordering is the
    # primary score and world-axis alignment is the tiebreaker. Must run with
    # geometry already in definition space.
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
      # LH instances: negate X for world-axis scoring so the search produces
      # the same perm+signs as the equivalent RH case. Only proper rotations
      # (det=+1) are applied, so handedness is preserved regardless.
      ax = inst_det < 0 ? Geom::Vector3d.new(-t.xaxis.x, -t.xaxis.y, -t.xaxis.z) : t.xaxis
      axes     = [ax, t.yaxis, t.zaxis]
      raw_axes = [t.xaxis, t.yaxis, t.zaxis]
      use_pre  = z_pre && x_pre

      best_score = -Float::INFINITY
      best_perm  = [0, 1, 2]
      best_signs = [1, 1, 1]

      # Enforce proper rotation: det(R_norm) = perm_det * sign_product = +1,
      # so sign_product must equal the permutation's determinant.
      [[[0,1,2], 1],[[0,2,1],-1],[[1,0,2],-1],
       [[1,2,0], 1],[[2,0,1], 1],[[2,1,0],-1]].each do |perm, pd|
        (pd > 0 ? [[1,1,1],[1,-1,-1],[-1,1,-1],[-1,-1,1]]
                : [[-1,1,1],[1,-1,1],[1,1,-1],[-1,-1,-1]]).each do |sx, sy, sz|
          if use_pre
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

      # SketchUp expects column-major; permutation + signs map to one nonzero
      # per column at row inv_perm[col].
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

    # Redefines local axes to minimise BB volume (3D path: two-phase ZYZ sweep
    # + Nelder-Mead) or area (flat path: normal align + 1D sweep). World
    # position is unchanged.
    def self.align_to_min_bb(instance, z_pre = nil, x_pre = nil)
      method_id  = __method__
      start_time = Time.now
      Debug.log(self, method_id, "Process START")

      begin
      # make_unique isolates siblings; bake_scale makes collect_vertices
      # reflect the actual shape when the instance has non-uniform scale.
      instance.make_unique if instance.is_a?(Sketchup::Group) && instance.definition.instances.size > 1
      bake_scale(instance)

      # Working in definition space makes the algorithm idempotent: a second
      # call sees already-rotated pts and the sweep returns identity.
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
        # planar_normal's sign is set by hull-vertex ordering; flip it to match
        # the face's front side when the definition has faces, so auto aligns
        # the chosen local axis with +face.normal, not -face.normal.
        face_n = signed_face_normal_for_def(instance.definition)
        if face_n && (normal[0]*face_n[0] + normal[1]*face_n[1] + normal[2]*face_n[2]) < 0
          normal = [-normal[0], -normal[1], -normal[2]]
        end
        nx, ny, nz = normal
        Debug.log(self, :align_pca, "planar geometry, normal=[#{nx.round(4)},#{ny.round(4)},#{nz.round(4)}]")

        # Nearest world axis to the normal. Always target the +axis so the chosen
        # local axis ends up pointing in the face's world-normal direction (not
        # just parallel). When antiparallel (cos_a < 0), the rl < 1e-8 branch
        # below generates the 180° flip that gets the sign right.
        axis_idx  = [[nx.abs, 0],[ny.abs, 1],[nz.abs, 2]].max_by{|v,_| v}[1]
        axes      = [[1,0,0],[0,1,0],[0,0,1]]
        ax, ay, az = axes[axis_idx]

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

        flat_axis_vec = Geom::Vector3d.new(*axes[axis_idx])
        r2      = Geom::Transformation.rotation(orig, flat_axis_vec, fine_angle)
        r_total = r2 * r1

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
        # The axis that r_total mapped the face normal onto must keep pointing
        # in the face's world-normal direction. Feed permute that world vector
        # as pre for the matching axis so its axis-preservation scoring doesn't
        # flip the sign back.
        n_world = t0 * Geom::Vector3d.new(nx, ny, nz)
        nwl     = Math.sqrt(n_world.x**2 + n_world.y**2 + n_world.z**2)
        if nwl > 1e-12
          n_world = Geom::Vector3d.new(n_world.x / nwl, n_world.y / nwl, n_world.z / nwl)
          z_pre_p = axis_idx == 2 ? n_world : z_pre
          x_pre_p = axis_idx == 0 ? n_world : x_pre
        else
          z_pre_p = z_pre; x_pre_p = x_pre
        end
        permute_axes_by_extent(instance, z_pre_p, x_pre_p)
        t1 = instance.transformation
        det1 = t1.xaxis.dot(t1.yaxis.cross(t1.zaxis)) >= 0 ? "RH" : "LH"
        Debug.log(self, :align_pca, "done (2D) handedness=#{det1}")
        return
      end

      # ── 3D path: auto-dispatch by hull size ────────────────────────────────
      # Crossover ~300 hull pts: face-flush (O(F·N²)) wins on small polyhedra;
      # ZYZ + Nelder-Mead (O(K·N)) wins as hull size grows.
      deg2rad = Math::PI / 180.0
      fine_vol = nil
      r_best   = nil

      if hull_pts.size < 300 && !hull_faces.empty?
        best = face_flush_min_bb(pts, hull_faces)
        if best.nil?
          Debug.log(self, :align_pca, "face-flush: no valid candidate")
          return
        end
        r11, r12, r13, r21, r22, r23, r31, r32, r33, fine_vol = best
        Debug.log(self, :align_pca, "face-flush best vol=#{fine_vol.round(4)}")

        r_best = Geom::Transformation.new([
          r11, r21, r31, 0,
          r12, r22, r32, 0,
          r13, r23, r33, 0,
          0,   0,   0,   1
        ])
      else
        # ZYZ Euler: R = Rz(α)·Ry(β)·Rz(γ). BB has 90° period in α and γ, so
        # the search space is [0°,90°) × [-90°,90°) × [0°,90°).
        eval_zyz = lambda do |al, be, ga|
          ca = Math.cos(al); sa = Math.sin(al)
          cb = Math.cos(be); sb = Math.sin(be)
          cg = Math.cos(ga); sg = Math.sin(ga)
          bb_vol_3d(pts,
            ca*cb*cg - sa*sg,  -ca*cb*sg - sa*cg,  ca*sb,
            sa*cb*cg + ca*sg,  -sa*cb*sg + ca*cg,  sa*sb,
            -sb*cg,             sb*sg,              cb)
        end

        # Coarse 15° grid (6×12×6 = 432 evals) to locate the basin.
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

        # Nelder-Mead simplex from the coarse best, initial edge 8°.
        s = 8.0 * deg2rad
        simplex = [
          [best_al,       best_be,       best_ga      ],
          [best_al + s,   best_be,       best_ga      ],
          [best_al,       best_be + s,   best_ga      ],
          [best_al,       best_be,       best_ga + s  ],
        ]
        fval = simplex.map { |v| eval_zyz.call(*v) }

        # 500-iter cap is a safety net: NM typically converges in <50 iters at
        # 1e-5 tolerance. Only near-degenerate input reaches the cap.
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

    # Rotates the definition so the chosen local axis points along dir_world
    # (world space: face normal or edge vector). The remaining two axes are
    # rolled around the locked axis to minimise in-plane BB area. World
    # geometry is unchanged; only local axes (and definition points) move.
    def self.align_to_direction_lock(instance, dir_world, lock_axis, z_pre = nil, x_pre = nil, min_bb: false)
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

      best_xw = best_yw = best_zw = nil

      # Fast path (O(1), no vertex scan): when pre-op axes are given and the
      # caller didn't ask for min-BB, project the in-plane pre-axis onto the
      # plane ⟂ n_hat; the third axis is the cross product. Falls through to
      # the hull-based path if that pre-axis is ~parallel to n_hat.
      if z_pre && x_pre && !min_bb
        ref = lock_axis == :x ? z_pre : x_pre
        rdot = ref.x * n_hat.x + ref.y * n_hat.y + ref.z * n_hat.z
        px = ref.x - rdot * n_hat.x
        py = ref.y - rdot * n_hat.y
        pz = ref.z - rdot * n_hat.z
        pl = Math.sqrt(px*px + py*py + pz*pz)
        if pl >= 1e-9
          in_plane = Geom::Vector3d.new(px / pl, py / pl, pz / pl)
          case lock_axis
          when :z
            best_xw = in_plane
            best_zw = n_hat
            best_yw = Geom::Vector3d.new(
              n_hat.y * in_plane.z - n_hat.z * in_plane.y,
              n_hat.z * in_plane.x - n_hat.x * in_plane.z,
              n_hat.x * in_plane.y - n_hat.y * in_plane.x
            )
          when :x
            best_zw = in_plane
            best_xw = n_hat
            best_yw = Geom::Vector3d.new(
              in_plane.y * n_hat.z - in_plane.z * n_hat.y,
              in_plane.z * n_hat.x - in_plane.x * n_hat.z,
              in_plane.x * n_hat.y - in_plane.y * n_hat.x
            )
          when :y
            best_xw = in_plane
            best_yw = n_hat
            best_zw = Geom::Vector3d.new(
              in_plane.y * n_hat.z - in_plane.z * n_hat.y,
              in_plane.z * n_hat.x - in_plane.x * n_hat.z,
              in_plane.x * n_hat.y - in_plane.y * n_hat.x
            )
          end
          Debug.log(self, method_id, "fast-path (analytical, no hull)")
        end
      end

      if best_xw.nil?
        world_pts = collect_vertices(instance.definition.entities, t)
        return if world_pts.empty?
        hull3d = convex_hull_3d(world_pts)
        hull3d = world_pts if hull3d.nil? || hull3d.size < 3

        fb = n_hat.z.abs > 0.9 ? Geom::Vector3d.new(1, 0, 0) : Geom::Vector3d.new(0, 0, 1)
        u0_raw = n_hat.cross(fb)
        ul = Math.sqrt(u0_raw.x**2 + u0_raw.y**2 + u0_raw.z**2)
        return if ul < 1e-12
        u0 = Geom::Vector3d.new(u0_raw.x / ul, u0_raw.y / ul, u0_raw.z / ul)
        v0 = n_hat.cross(u0)

        proj = hull3d.map { |p| [p.x*u0.x + p.y*u0.y + p.z*u0.z, p.x*v0.x + p.y*v0.y + p.z*v0.z] }
        hull2d = convex_hull_2d(proj)
        return if hull2d.size < 2

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

        # Four 90° rotations of the non-locked axes; each pair (a,b) has a×b = n_hat.
        rot_pairs = [[u_opt, v_opt], [v_opt, neg_u], [neg_u, neg_v], [neg_v, u_opt]]

        y_pre = nil
        if z_pre && x_pre
          y_pre = Geom::Vector3d.new(
            z_pre.y * x_pre.z - z_pre.z * x_pre.y,
            z_pre.z * x_pre.x - z_pre.x * x_pre.z,
            z_pre.x * x_pre.y - z_pre.y * x_pre.x
          )
        end

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

        Debug.log(self, method_id, "min rect area=#{best_area.round(4)}")
      end

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

    # Aligns target's axes to sample's axes in WORLD coordinates, preserving
    # target's world origin and uniform scale. Groups make_unique (SketchUp
    # convention); components keep the shared definition so all instances
    # pick up the new axes together. Composes `edit_transform` so nested
    # edit contexts don't break the math.
    def self.align_to_sample(target, sample)
      method_id = __method__
      target.make_unique if target.is_a?(Sketchup::Group) && target.definition.instances.size > 1
      bake_scale(target)

      et = Sketchup.active_model.edit_transform

      sw = et * sample.transformation
      xs = sw.xaxis; zs = sw.zaxis
      xl = Math.sqrt(xs.x**2 + xs.y**2 + xs.z**2)
      zl = Math.sqrt(zs.x**2 + zs.y**2 + zs.z**2)
      return if xl < 1e-12 || zl < 1e-12
      xw = Geom::Vector3d.new(xs.x / xl, xs.y / xl, xs.z / xl)
      zw = Geom::Vector3d.new(zs.x / zl, zs.y / zl, zs.z / zl)
      yw = Geom::Vector3d.new(
        zw.y * xw.z - zw.z * xw.y,
        zw.z * xw.x - zw.x * xw.z,
        zw.x * xw.y - zw.y * xw.x
      )
      yl = Math.sqrt(yw.x**2 + yw.y**2 + yw.z**2)
      return if yl < 1e-9
      yw = Geom::Vector3d.new(yw.x / yl, yw.y / yl, yw.z / yl)
      zw = Geom::Vector3d.new(
        xw.y * yw.z - xw.z * yw.y,
        xw.z * yw.x - xw.x * yw.z,
        xw.x * yw.y - xw.y * yw.x
      )

      Debug.log(self, method_id, "sample world axes: " \
        "X=[#{xw.x.round(4)},#{xw.y.round(4)},#{xw.z.round(4)}] " \
        "Y=[#{yw.x.round(4)},#{yw.y.round(4)},#{yw.z.round(4)}] " \
        "Z=[#{zw.x.round(4)},#{zw.y.round(4)},#{zw.z.round(4)}]")

      tw  = et * target.transformation
      twa = tw.to_a
      st  = Math.sqrt(twa[0]**2 + twa[1]**2 + twa[2]**2)
      st  = 1.0 if st < 1e-12
      ow  = tw.origin

      tx_b = tw.xaxis; ty_b = tw.yaxis; tz_b = tw.zaxis
      txb_l = Math.sqrt(tx_b.x**2 + tx_b.y**2 + tx_b.z**2)
      tyb_l = Math.sqrt(ty_b.x**2 + ty_b.y**2 + ty_b.z**2)
      tzb_l = Math.sqrt(tz_b.x**2 + tz_b.y**2 + tz_b.z**2)
      Debug.log(self, method_id, "target world axes BEFORE: " \
        "X=[#{(tx_b.x/txb_l).round(4)},#{(tx_b.y/txb_l).round(4)},#{(tx_b.z/txb_l).round(4)}] " \
        "Y=[#{(ty_b.x/tyb_l).round(4)},#{(ty_b.y/tyb_l).round(4)},#{(ty_b.z/tyb_l).round(4)}] " \
        "Z=[#{(tz_b.x/tzb_l).round(4)},#{(tz_b.y/tzb_l).round(4)},#{(tz_b.z/tzb_l).round(4)}]")

      arr = [
        xw.x * st, xw.y * st, xw.z * st, 0.0,
        yw.x * st, yw.y * st, yw.z * st, 0.0,
        zw.x * st, zw.y * st, zw.z * st, 0.0,
        ow.x,      ow.y,      ow.z,      1.0
      ]
      desired_world = Geom::Transformation.new(arr)

      # Mutate the definition by m and compensate every instance with m.inverse
      # so world positions stay put while all instances share the new local axes.
      m     = desired_world.inverse * tw
      m_inv = m.inverse
      ents  = target.definition.entities
      ents.transform_entities(m, ents.to_a)
      target.definition.instances.each do |inst|
        inst.transformation = inst.transformation * m_inv
      end

      tw2  = et * target.transformation
      tx_a = tw2.xaxis; ty_a = tw2.yaxis; tz_a = tw2.zaxis
      txa_l = Math.sqrt(tx_a.x**2 + tx_a.y**2 + tx_a.z**2)
      tya_l = Math.sqrt(ty_a.x**2 + ty_a.y**2 + ty_a.z**2)
      tza_l = Math.sqrt(tz_a.x**2 + tz_a.y**2 + tz_a.z**2)
      Debug.log(self, method_id, "target world axes AFTER:  " \
        "X=[#{(tx_a.x/txa_l).round(4)},#{(tx_a.y/txa_l).round(4)},#{(tx_a.z/txa_l).round(4)}] " \
        "Y=[#{(ty_a.x/tya_l).round(4)},#{(ty_a.y/tya_l).round(4)},#{(ty_a.z/tya_l).round(4)}] " \
        "Z=[#{(tz_a.x/tza_l).round(4)},#{(tz_a.y/tza_l).round(4)},#{(tz_a.z/tza_l).round(4)}]")
    end

    class OEAlignerTool

      BB_EDGES = [[0,1],[0,2],[1,3],[2,3],[4,5],[4,6],[5,7],[6,7],[0,4],[1,5],[2,6],[3,7]].freeze
      BB_FACES = [
        [0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1],
        [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3],
      ].freeze

      MODE_CYCLE = [:entity, :reference, :auto].freeze
      AXIS_CYCLE = [:z, :x, :y].freeze

      AXIS_COLOR = {
        z: Sketchup::Color.new(50, 100, 255),
        x: Sketchup::Color.new(255, 80, 80),
        y: Sketchup::Color.new(50, 180, 50),
      }.freeze

      # Per-mode highlight colours. INVALID_RED flags a :reference target that
      # shares the sample's definition (clicking would be a no-op).
      FUCHSIA     = Sketchup::Color.new(255, 0, 200).freeze
      CYAN        = Sketchup::Color.new(0, 180, 200).freeze
      ORANGE      = Sketchup::Color.new(255, 165, 0).freeze
      INVALID_RED = Sketchup::Color.new(255, 0, 0).freeze

      @@last_mode      = :entity
      @@last_lock_axis = :z

      def self.cursor_id
        @@cursor_id ||= begin
          ext  = Sketchup.platform == :platform_win ? 'svg' : 'pdf'
          path = File.join(PATH_CURSORS, "oe_aligner_32.#{ext}")
          UI.create_cursor(path, 5, 5)
        end
      end

      def initialize(instances)
        @model          = Sketchup.active_model
        @instances      = instances
        @hovered        = nil
        @mode           = @@last_mode
        @lock_axis      = @@last_lock_axis
        @alt_handled    = false
        @hover_kind     = nil
        @hover_entity   = nil
        @hover_loops    = nil
        @hover_segment  = nil
        @hover_dir      = nil
        @hover_fill_pts = nil
        @hover_centroid = nil
        # :reference-mode source. Raw edge/face: geometry in model root.
        # Component/group: sample whose local axis becomes the target direction.
        @ref_entity     = nil
        @ref_kind       = nil
        @ref_loops      = nil
        @ref_segment    = nil
        @ref_fill_pts   = nil
        @ref_dir        = nil
        @ref_centroid   = nil
        @last_x         = nil
        @last_y         = nil
      end

      def activate
        @model.selection.clear unless @model.selection.empty?
        update_vcb
        if @mode == :auto
          UI.start_timer(0, false) { apply_auto(@instances) unless @instances.empty? }
        end
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
        @last_x = x
        @last_y = y
        pick_at(x, y, view)
      end

      def pick_at(x, y, view, force_recapture: false)
        ph = view.pick_helper
        ph.do_pick(x, y)

        case @mode
        when :auto      then pick_auto(ph, view)
        when :reference then pick_reference(ph, view, force_recapture: force_recapture)
        else                 pick_entity(ph, view, force_recapture: force_recapture)
        end
      end

      def pick_auto(ph, view)
        entity = ph.best_picked
        candidate = (entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)) ? entity : nil
        if candidate != @hovered
          @hovered = candidate
          clear_hover_geom
          view.invalidate
        end
      end

      def pick_entity(ph, view, force_recapture: false)
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

        changed = force_recapture || (leaf != @hover_entity) || (outer != @hovered)
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

      # Prefers raw edges/faces (direction reference); falls back to a
      # component/group hover, which is clickable either as a sample (no ref
      # yet) or as an alignment target (ref already stored).
      def pick_reference(ph, view, force_recapture: false)
        raw_leaf = nil; raw_t = nil
        ph.count.times do |i|
          cand = ph.leaf_at(i)
          next unless cand.is_a?(Sketchup::Face) || cand.is_a?(Sketchup::Edge)
          path = ph.path_at(i) || []
          next if path.any? { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }
          raw_leaf = cand
          raw_t    = ph.transformation_at(i) || Geom::Transformation.new
          break
        end

        if raw_leaf
          changed = force_recapture || raw_leaf != @hover_entity || @hovered
          if changed
            @hover_entity = raw_leaf
            @hovered      = nil
            clear_hover_geom
            case raw_leaf
            when Sketchup::Face then capture_hover_face(raw_leaf, raw_t)
            when Sketchup::Edge then capture_hover_edge(raw_leaf, raw_t)
            end
            sync_hover_preview_selection
            view.invalidate
          end
          return
        end

        instance = nil
        ph.count.times do |i|
          path = ph.path_at(i) || []
          inst = path.first
          if inst.is_a?(Sketchup::ComponentInstance) || inst.is_a?(Sketchup::Group)
            instance = inst
            break
          end
        end

        if instance != @hovered || @hover_entity
          @hovered      = instance
          @hover_entity = nil
          clear_hover_geom
          sync_hover_preview_selection
          view.invalidate
        end
      end

      def draw(view)
        eye = view.camera.eye

        # Sample visualisation: SketchUp draws it natively via model.selection
        # (added in promote_hovered_to_sample). Same goes for the hover preview
        # in :reference mode when no sample has been set yet.

        if @hovered && @hovered.valid? && @hovered != @ref_entity
          native_preview = @mode == :reference && @ref_entity.nil?
          unless native_preview
            invalid  = @mode == :reference && hover_invalid?
            bb_color = case @mode
                       when :auto      then ORANGE
                       when :reference then invalid ? INVALID_RED : CYAN
                       else                 FUCHSIA
                       end
            draw_bbox(view, eye, @hovered, bb_color, fill: invalid)
          end
        end

        return if @mode == :auto

        axis_color = AXIS_COLOR[@lock_axis]
        draw_reference_ref(view, eye, axis_color) if @mode == :reference

        if @hover_entity && @hover_entity.valid?
          if @mode == :reference
            draw_reference_hover(view, eye, axis_color)
          else
            draw_entity_hover(view, eye, axis_color)
          end
        end
      end

      def draw_bbox(view, eye, instance, color, fill: false)
        t       = instance.transformation
        def_bb  = instance.definition.bounds
        corners = 8.times.map { |i| t * def_bb.corner(i) }
        if fill
          view.drawing_color = Sketchup::Color.new(color.red, color.green, color.blue, 80)
          BB_FACES.each do |quad|
            view.draw(GL_QUADS, quad.map { |i| corners[i] })
          end
        end
        view.line_width    = 2
        view.drawing_color = color
        BB_EDGES.each do |a, b|
          pa = corners[a].offset((eye - corners[a]).normalize, 0.1)
          pb = corners[b].offset((eye - corners[b]).normalize, 0.1)
          view.draw(GL_LINES, [pa, pb])
        end
      end

      def sample_ref?
        @ref_kind == :component || @ref_kind == :group
      end

      # Hovered target is a copy of the sample component (same definition) →
      # clicking would rotate the sample relative to itself. Groups are skipped:
      # each group carries its own geometry, so "same group" can only mean the
      # literal sample instance, handled by the earlier `@hovered != @ref_entity`
      # guard.
      def hover_invalid?
        return false unless @ref_kind == :component
        return false unless @hovered.is_a?(Sketchup::ComponentInstance)
        return false unless @ref_entity && @ref_entity.valid?
        @hovered.definition == @ref_entity.definition
      end

      def draw_entity_hover(view, eye, color)
        case @hover_kind
        when :face
          return unless @hover_loops
          fill = Sketchup::Color.new(color.red, color.green, color.blue, 80)
          if @hover_fill_pts && !@hover_fill_pts.empty?
            view.drawing_color = fill
            view.draw(GL_TRIANGLES, @hover_fill_pts)
          end
          view.line_width    = 2
          view.drawing_color = color
          @hover_loops.each do |loop_pts|
            offset_pts = loop_pts.map { |p| p.offset((eye - p).normalize, 0.1) }
            view.draw(GL_LINE_LOOP, offset_pts)
          end
          draw_direction_arrow(view, @hover_centroid, @hover_dir, color) if @hover_centroid && @hover_dir
        when :edge
          return unless @hover_segment
          view.line_width    = 4
          view.drawing_color = color
          seg = @hover_segment.map { |p| p.offset((eye - p).normalize, 0.1) }
          view.draw(GL_LINES, seg)
        end
      end

      def draw_reference_hover(view, eye, axis_color)
        return if @hover_entity == @ref_entity  # avoid overdrawing the reference
        case @hover_kind
        when :face
          return unless @hover_loops
          draw_face_body(view, eye, @hover_loops, @hover_fill_pts, axis_color, axis_color)
          draw_direction_arrow(view, @hover_centroid, @hover_dir, axis_color) if @hover_centroid && @hover_dir
        when :edge
          return unless @hover_segment
          view.line_width    = 4
          view.drawing_color = axis_color
          seg = @hover_segment.map { |p| p.offset((eye - p).normalize, 0.1) }
          view.draw(GL_LINES, seg)
        end
      end

      def draw_reference_ref(view, eye, axis_color)
        return unless @ref_entity && @ref_entity.valid?
        case @ref_kind
        when :face
          return unless @ref_loops
          draw_face_body(view, eye, @ref_loops, @ref_fill_pts, axis_color, axis_color)
          draw_direction_arrow(view, @ref_centroid, @ref_dir, axis_color) if @ref_centroid && @ref_dir
        when :edge
          return unless @ref_segment
          view.line_width    = 4
          view.drawing_color = axis_color
          seg = @ref_segment.map { |p| p.offset((eye - p).normalize, 0.1) }
          view.draw(GL_LINES, seg)
        end
      end

      def draw_face_body(view, eye, loops, fill_pts, fill_color, border_color)
        fill = Sketchup::Color.new(fill_color.red, fill_color.green, fill_color.blue, 80)
        if fill_pts && !fill_pts.empty?
          view.drawing_color = fill
          view.draw(GL_TRIANGLES, fill_pts)
        end
        view.line_width    = 2
        view.drawing_color = border_color
        loops.each do |loop_pts|
          offset_pts = loop_pts.map { |p| p.offset((eye - p).normalize, 0.1) }
          view.draw(GL_LINE_LOOP, offset_pts)
        end
      end

      def draw_direction_arrow(view, centroid, dir, color)
        p1     = centroid.offset((view.camera.eye - centroid).normalize, 0.1)
        len_px = [view.vpheight * 0.1, 50].max
        len    = view.pixels_to_model(len_px, p1)
        p2     = p1.offset(dir, len)
        view.line_width    = 4
        view.drawing_color = color
        view.draw(GL_LINES, [p1, p2])
      end

      def getExtents
        bb = Geom::BoundingBox.new
        if @hovered && @hovered.valid?
          t = @hovered.transformation
          8.times { |i| bb.add(t * @hovered.definition.bounds.corner(i)) }
        end
        @hover_loops.each { |loop_pts| loop_pts.each { |p| bb.add(p) } } if @hover_loops
        @hover_segment.each { |p| bb.add(p) } if @hover_segment
        @ref_loops.each   { |loop_pts| loop_pts.each { |p| bb.add(p) } } if @ref_loops
        @ref_segment.each { |p| bb.add(p) } if @ref_segment
        bb
      end

      def enableVCB?
        true
      end

      def onSetCursor
        UI.set_cursor(OEAlignerTool.cursor_id)
      end

      def onLButtonDown(flags, x, y, view)
        case @mode
        when :auto
          ph = view.pick_helper
          ph.do_pick(x, y)
          entity = ph.best_picked
          return unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          apply_auto([entity])
        when :reference
          ctrl = (flags & COPY_MODIFIER_MASK) != 0
          if @hover_entity && @hover_entity.valid? && @hover_dir
            return if @hover_entity == @ref_entity  # click on current ref: no-op
            promote_hover_to_reference
            update_vcb
            view.invalidate
          elsif @hovered && @hovered.valid?
            if ctrl || @ref_entity.nil?
              promote_hovered_to_sample(view)
            elsif @ref_dir && !hover_invalid?
              apply_lock(@hovered, @ref_dir, @lock_axis)
            end
          end
        else
          return unless @hovered && @hovered.valid? && @hover_dir
          apply_lock(@hovered, @hover_dir, @lock_axis)
        end
      end

      def onKeyDown(key, _repeat, _flags, view)
        case key
        when 18 # Alt — cycle mode (entity → reference → auto)
          toggle_mode(view)
          @alt_handled = true
        when 9  # Tab — cycle axis (entity or reference mode)
          cycle_axis(view) if @mode == :entity || @mode == :reference
        end
      end

      def onKeyUp(key, _repeat, _flags, view)
        if key == 18 # Alt — fallback if key-down was swallowed by the OS
          toggle_mode(view) unless @alt_handled
          @alt_handled = false
        end
      end

      private

      def toggle_mode(view)
        idx = MODE_CYCLE.index(@mode) || 0
        @mode = MODE_CYCLE[(idx + 1) % MODE_CYCLE.size]
        @@last_mode = @mode
        clear_reference
        clear_hover
        update_vcb
        view.invalidate
      end

      def cycle_axis(view)
        idx = AXIS_CYCLE.index(@lock_axis) || 0
        @lock_axis = AXIS_CYCLE[(idx + 1) % AXIS_CYCLE.size]
        @@last_lock_axis = @lock_axis
        refresh_sample_direction
        update_vcb
        view.invalidate
      end

      def promote_hovered_to_sample(view)
        instance = @hovered
        dir = sample_axis_direction(instance, @lock_axis)
        return unless dir
        clear_reference
        @ref_entity   = instance
        @ref_kind     = instance.is_a?(Sketchup::Group) ? :group : :component
        @ref_dir      = dir
        @ref_centroid = instance.transformation.origin
        @model.selection.clear
        @model.selection.add(instance)
        update_vcb
        view.invalidate
      end

      def refresh_sample_direction
        return unless sample_ref? && @ref_entity && @ref_entity.valid?
        dir = sample_axis_direction(@ref_entity, @lock_axis)
        @ref_dir      = dir if dir
        @ref_centroid = @ref_entity.transformation.origin
      end

      def sample_axis_direction(instance, lock_axis)
        t = instance.transformation
        v = case lock_axis
            when :z then t.zaxis
            when :x then t.xaxis
            when :y then t.yaxis
            end
        vl = v.length
        return nil if vl < 1e-12
        Geom::Vector3d.new(v.x / vl, v.y / vl, v.z / vl)
      end

      def clear_hover
        @hovered      = nil
        @hover_entity = nil
        clear_hover_geom
        sync_hover_preview_selection
      end

      # Mirrors @hovered into the model selection so SketchUp draws its native
      # bbox preview. Only active in :reference mode before a sample is set.
      def sync_hover_preview_selection
        return unless @mode == :reference && @ref_entity.nil?
        desired = (@hovered && @hovered.valid?) ? [@hovered] : []
        sel = @model.selection
        current = sel.to_a
        return if current == desired
        sel.clear unless sel.empty?
        sel.add(desired) unless desired.empty?
      end

      def clear_hover_geom
        @hover_kind     = nil
        @hover_loops    = nil
        @hover_segment  = nil
        @hover_dir      = nil
        @hover_fill_pts = nil
        @hover_centroid = nil
      end

      def clear_reference
        @ref_entity   = nil
        @ref_kind     = nil
        @ref_loops    = nil
        @ref_segment  = nil
        @ref_fill_pts = nil
        @ref_dir      = nil
        @ref_centroid = nil
        @model.selection.clear unless @model.selection.empty?
      end

      def promote_hover_to_reference
        @ref_entity   = @hover_entity
        @ref_kind     = @hover_kind
        @ref_loops    = @hover_loops
        @ref_segment  = @hover_segment
        @ref_fill_pts = @hover_fill_pts
        @ref_dir      = @hover_dir
        @ref_centroid = @hover_centroid
        # An edge/face ref supersedes any prior component/group sample highlight.
        @model.selection.clear unless @model.selection.empty?
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

        # Canonicalize direction: the dominant absolute component is always positive.
        ax, ay, az = dx.abs, dy.abs, dz.abs
        dominant   = (ax >= ay && ax >= az) ? dx : (ay >= az ? dy : dz)
        sign       = dominant < 0 ? -1.0 : 1.0

        @hover_kind     = :edge
        @hover_segment  = [a, b]
        @hover_centroid = Geom::Point3d.new((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, (a.z + b.z) * 0.5)
        @hover_dir      = Geom::Vector3d.new(sign * dx / dl, sign * dy / dl, sign * dz / dl)
      end

      def apply_auto(instances)
        return if instances.empty?
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

      # Sign-sensitive: antiparallel counts as misaligned (triggers a flip).
      def axis_already_aligned?(instance, dir_world, lock_axis)
        current = case lock_axis
                  when :z then instance.transformation.zaxis
                  when :x then instance.transformation.xaxis
                  when :y then instance.transformation.yaxis
                  end
        return false unless current && dir_world
        cl = current.length
        dl = dir_world.length
        return false if cl < 1e-9 || dl < 1e-9
        cos = current.dot(dir_world) / (cl * dl)
        cos >= 1.0 - 1e-9
      end

      def apply_lock(instance, dir_world, lock_axis)
        # Component/group sample copies all three axes, so skip only if all
        # three already match — locked-axis coincidence alone is not enough.
        if sample_ref? && @ref_entity && @ref_entity.valid?
          return if fully_aligned_with_sample?(instance, @ref_entity)
          @model.start_operation("Orienter Express: Align to Sample", true)
          begin
            OrienterExpress.send(:align_to_sample, instance, @ref_entity)
            @model.commit_operation
            clear_hover
            view = @model.active_view
            pick_at(@last_x, @last_y, view, force_recapture: true) if @last_x && @last_y
            view.invalidate
          rescue => e
            @model.abort_operation
            UI.messagebox("Error: #{e.message}")
          end
          return
        end

        return if axis_already_aligned?(instance, dir_world, lock_axis)
        z_pre = instance.transformation.zaxis
        x_pre = instance.transformation.xaxis
        # :entity → full-component min-BB (slower but picks the rotation that
        # actually minimises the component's in-plane bbox).
        # :reference → axis-preserving fast-path (no vertex scan).
        use_min_bb = @mode == :entity
        @model.start_operation("Orienter Express: Direction-Lock Alignment", true)
        begin
          OrienterExpress.send(:align_to_direction_lock, instance, dir_world, lock_axis,
                               z_pre, x_pre, min_bb: use_min_bb)
          @model.commit_operation
          clear_hover
          view = @model.active_view
          if @last_x && @last_y
            pick_at(@last_x, @last_y, view, force_recapture: true)
          end
          view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

      def fully_aligned_with_sample?(instance, sample)
        ti = instance.transformation
        ts = sample.transformation
        pairs = [[ti.xaxis, ts.xaxis], [ti.yaxis, ts.yaxis], [ti.zaxis, ts.zaxis]]
        pairs.all? do |a, b|
          al = a.length; bl = b.length
          next false if al < 1e-9 || bl < 1e-9
          (a.dot(b) / (al * bl)).abs >= 1.0 - 1e-9
        end
      end

      def update_vcb
        mode_key = case @mode
                   when :entity    then :mode_entity
                   when :reference then :mode_reference
                   else                 :mode_auto
                   end
        mode_label = Lang.commands.oealigner.send(mode_key).to_s.upcase

        axis_label = case @lock_axis
                     when :z then Lang.commands.oealigner.axis_z
                     when :x then Lang.commands.oealigner.axis_x
                     when :y then Lang.commands.oealigner.axis_y
                     end

        case @mode
        when :entity
          desc = Lang.commands.oealigner.desc_entity.to_s
          hint = format(Lang.commands.oealigner.vcb_hint_entity.to_s,
                        mode: mode_label.to_s, axis: axis_label.to_s)
        when :reference
          if @ref_entity
            desc = Lang.commands.oealigner.desc_reference_target.to_s
            hint = format(Lang.commands.oealigner.vcb_hint_reference_target.to_s,
                          mode: mode_label.to_s, axis: axis_label.to_s)
          else
            desc = Lang.commands.oealigner.desc_reference_ref.to_s
            hint = format(Lang.commands.oealigner.vcb_hint_reference_ref.to_s,
                          mode: mode_label.to_s, axis: axis_label.to_s)
          end
        else
          desc = Lang.commands.oealigner.desc_auto.to_s
          hint = format(Lang.commands.oealigner.vcb_hint_auto.to_s, mode: mode_label.to_s)
        end
        Sketchup.set_status_text("#{desc}  |  #{hint}", 0)
      end
    end

    def self.oealigner
      model   = Sketchup.active_model
      targets = instances(model.selection)
      model.select_tool(OEAlignerTool.new(targets))
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
    private_class_method :align_to_sample
    private_class_method :bake_scale
    private_class_method :orient_ground
    private_class_method :orient_ground_around
    private_class_method :orient_to_flow_around
    private_class_method :orient_to_face_normal_around
    private_class_method :orient_to_flow
    private_class_method :face_centroid
    private_class_method :resolved_pivot
    private_class_method :move_pivot_to
    private_class_method :vertex_flow_direction
    private_class_method :all_vertex_flow_directions
    private_class_method :average_outward_dirs
    private_class_method :diffuse_flow_directions
    private_class_method :inherit_endpoint_dirs

  end # module OrienterExpress
end # module ASM_Extensions
