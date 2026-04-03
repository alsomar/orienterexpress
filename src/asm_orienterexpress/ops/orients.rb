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

    # Rotates the entity around its local Z axis so that the local Y axis
    # aligns to the average flow direction of the edge's vertices, projected
    # onto the plane perpendicular to Z. Falls back to orient_x if degenerate.
    def self.orient_to_flow(entity, edge, flow_map)
      method_id  = :orient_to_flow
      z_axis     = entity.transformation.zaxis
      flow_start = flow_map[edge.start]
      flow_end   = flow_map[edge.end]
      candidates = [flow_start, flow_end].compact

      Debug.log(self, method_id,
        "edge #{edge.start.position.to_a.map { |v| v.round(2) }} → " \
        "#{edge.end.position.to_a.map { |v| v.round(2) }} | " \
        "flow_start=#{flow_start&.to_a&.map { |v| v.round(3) } || 'nil'} " \
        "flow_end=#{flow_end&.to_a&.map { |v| v.round(3) } || 'nil'}")

      if candidates.empty?
        Debug.log(self, method_id, "  → fallback: no flow data")
        orient_x(entity)
        return
      end

      avg = candidates.reduce(Geom::Vector3d.new(0, 0, 0)) { |s, v| s + v }
      if avg.length < 1e-6
        Debug.log(self, method_id, "  → fallback: avg cancelled out")
        orient_x(entity)
        return
      end
      avg.normalize!

      # Project onto plane perpendicular to local Z
      dot       = z_axis.dot(avg)
      proj_z    = Geom::Vector3d.new(z_axis.x * dot, z_axis.y * dot, z_axis.z * dot)
      projected = avg - proj_z

      Debug.log(self, method_id,
        "  z_axis=#{z_axis.to_a.map { |v| v.round(3) }} avg=#{avg.to_a.map { |v| v.round(3) }} " \
        "dot=#{dot.round(3)} projected=#{projected.to_a.map { |v| v.round(3) }} len=#{projected.length.round(4)}")

      if projected.length < 1e-6
        Debug.log(self, method_id, "  → fallback: flow parallel to edge")
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

      Debug.log(self, method_id,
        "  → aligned: y_before=#{y_before.to_a.map { |v| v.round(3) }} " \
        "target=#{target.to_a.map { |v| v.round(3) }} " \
        "y_after=#{entity.transformation.yaxis.to_a.map { |v| v.round(3) }}")
    end

    # Rotates the entity around its local Z axis so that the local Y axis
    # aligns to the averaged normal of the faces sharing the edge, projected
    # onto the plane perpendicular to Z. Falls back to orient_x if degenerate.
    def self.orient_to_face_normal(entity, edge)
      normals = edge.faces.map(&:normal).select { |n| n.length > 1e-6 }.map(&:normalize)
      return orient_x(entity) if normals.empty?

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
    def self.orient_to_face_edge(entity, face, axis_idx)
      axes = face_longest_edge_axes(face)
      return orient_x(entity) unless axes

      target = axes[axis_idx % 2]
      z_axis = entity.transformation.zaxis.normalize
      x_axis = entity.transformation.xaxis.normalize

      dot       = z_axis.dot(target)
      projected = target - Geom::Vector3d.new(z_axis.x * dot, z_axis.y * dot, z_axis.z * dot)
      return orient_x(entity) if projected.length < 1e-6

      target_n = projected.normalize
      cross    = x_axis.cross(target_n)
      sin_val  = cross.dot(z_axis)
      angle    = Math.atan2(sin_val, x_axis.dot(target_n))

      unless angle.abs < 1e-6
        entity.transform!(Geom::Transformation.rotation(entity.bounds.center, z_axis, angle))
      end
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

    # Returns the effective insertion mode for a tool from per-tool config.
    def self.resolved_insertion_point(tool_key)
      custom = CONFIG[:insertion_point_custom]
      (custom.is_a?(Hash) && custom[tool_key]) || 'center'
    end

    # Moves the entity so the resolved insertion point lands on the target.
    #   'origin' — local coordinate origin (transformation.origin)
    #   'center' — bounding-box centre (default)
    #   'base'   — centre of the bottom face in definition space
    def self.move_insertion_to(entity, point, tool_key)
      entity_ref = case resolved_insertion_point(tool_key)
                   when 'origin'
                     entity.transformation.origin
                   when 'base'
                     db           = entity.definition.bounds
                     local_bottom = Geom::Point3d.new(db.center.x, db.center.y, db.min.z)
                     entity.transformation * local_bottom
                   else # 'center'
                     entity.bounds.center
                   end
      entity.transform!(Geom::Transformation.translation(point - entity_ref))
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
      sum = Geom::Vector3d.new(dirs.sum(&:x), dirs.sum(&:y), dirs.sum(&:z))
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
        fn_sum = Geom::Vector3d.new(face_normals.sum(&:x), face_normals.sum(&:y), face_normals.sum(&:z))
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

    def self.oeedgevertex
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

      op_name = "Orienter Express: Edge Vertex"
      model.start_operation(op_name, true)
      Debug.log(self, method_id, "Process START")

      begin
        edges.each do |edge|
          next if edge.length.zero?
          edge_dir = (edge.end.position - edge.start.position).normalize

          [
            [edge.start.position, edge_dir],
            [edge.end.position,   edge_dir.reverse]
          ].each do |target_point, direction|
            entity_copy = create_entity_copy(entity_def, entity_t)
            t = entity_copy.transformation
            align_axis(entity_copy, t.origin, t.zaxis, direction)
            orient_x(entity_copy)
            move_insertion_to(entity_copy, target_point, :oeedgevertex)
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
          midpoint = Geom::Point3d.linear_combination(0.5, edge.start.position, 0.5, edge.end.position)
          move_insertion_to(entity_copy, midpoint, :oecenter)
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


    # Tool class for interactive Z-Scaling.
    # The user adjusts the offset via the VCB; each Enter re-applies the
    # operation so the result updates in real time.
    # Escape undoes the last preview and exits. Switching tools commits.
    class OEZScaleTool

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
        @@last_offset_str ||= CONFIG[:oezscale_offset] || "10cm"
      end

      def self.last_offset_str=(val)
        @@last_offset_str = val
        OrienterExpress.user_settings(oezscale_offset: val)
      end

      def initialize(edges, entity_def, entity_t, flow_map, rotation_mode)
        @edges             = edges
        @entity_def        = entity_def
        @entity_t          = entity_t
        @flow_map          = flow_map
        @rotation_mode     = rotation_mode
        @model             = Sketchup.active_model
        @applied           = false
        @first_apply       = true
        @previous_entities = []
        @entity_to_edge    = {}
      end

      def activate
        @skipped_edges = []
        @lbutton_down  = false
        @drag_mode     = nil
        @sample_mode   = false
        @watcher = SelectionWatcher.new { on_external_selection_change }
        @model.selection.add_observer(@watcher)
        update_vcb
        UI.start_timer(0, false) { apply(OEZScaleTool.last_offset_str); sync_selection }
      end

      def deactivate(view)
        @model.selection.remove_observer(@watcher) if @watcher
        @watcher           = nil
        @applied           = false
        @previous_entities = []
        @skipped_edges     = []
        @entity_to_edge    = {}
        view.invalidate
      end

      def draw(view)
        draw_sample_bounds(view)

        return if @skipped_edges.nil? || @skipped_edges.empty?

        view.invalidate
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

      def draw_sample_bounds(view)
        bounds = @entity_def.bounds
        return if bounds.empty?

        eye     = view.camera.eye
        corners = 8.times.map do |i|
          pt = @entity_t * bounds.corner(i)
          pt.offset((eye - pt).normalize, 0.1)
        end
        pairs = [[0,1],[0,2],[1,3],[2,3],[4,5],[4,6],[5,7],[6,7],[0,4],[1,5],[2,6],[3,7]]

        view.line_width = 3
        view.drawing_color = Sketchup::Color.new(255, 140, 0)
        pairs.each do |a, b|
          view.draw(GL_LINES, [corners[a], corners[b]])
        end
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
        bb = Geom::BoundingBox.new
        @entity_def.bounds.corners.each { |c| bb.add(@entity_t * c) }
        bb
      end

      def onSetCursor
        update_cursor
      end

      def onLButtonDown(flags, x, y, view)
        if @sample_mode
          pick_new_sample(view, x, y)
          return
        end
        @lbutton_down = true
        @syncing = true
        saved = @edges.dup
        handle_click(flags, x, y, view, :single)
        @edges = saved if @edges.empty? && !saved.empty?
        sync_selection
      ensure
        @syncing = false
      end

      def onLButtonDoubleClick(flags, x, y, view)
        @syncing = true
        saved = @edges.dup
        handle_click(flags, x, y, view, :double)
        @edges = saved if @edges.empty? && !saved.empty?
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
          puts "[OEZScale.mouseMove] flags=0x#{flags.to_s(16)}  ctrl:#{@mod_ctrl}→#{ctrl}  shift:#{@mod_shift}→#{shift}  sample:#{@sample_mode}"
          @mod_ctrl  = ctrl
          @mod_shift = shift
          update_cursor
          view.invalidate
        end
        if @lbutton_down && @drag_mode && (ctrl || shift)
          picked_edges = pick_edges(view, x, y)
          modify_edges(@drag_mode, picked_edges) if picked_edges
        end
        view.invalidate unless @skipped_edges.nil? || @skipped_edges.empty?
      end

      def onUserText(text, _view)
        return if text.strip.empty?
        apply(text.strip)
      end


      def onKeyDown(key, _repeat, flags, view)
        before_sample = @sample_mode
        before_ctrl   = @mod_ctrl
        before_shift  = @mod_shift
        case key
        when 17 then @mod_ctrl = true;  @sample_mode = false
        when 16 then @mod_shift = true; @sample_mode = false
        when 38 then @sample_mode = !@sample_mode
        else
          @mod_ctrl  = flags & COPY_MODIFIER_MASK      != 0
          @mod_shift = flags & CONSTRAIN_MODIFIER_MASK != 0
        end
        key_name = { 16 => "Shift", 17 => "Ctrl", 27 => "Esc", 9 => "Tab", 37 => "Left", 38 => "Up", 39 => "Right", 40 => "Down" }[key] || "key#{key}"
        puts "[OEZScale.keyDown] #{key_name} flags=0x#{flags.to_s(16)}  ctrl:#{before_ctrl}→#{@mod_ctrl}  shift:#{before_shift}→#{@mod_shift}  sample:#{before_sample}→#{@sample_mode}"
        update_cursor
        view.invalidate
        case key
        when 27 # VK_ESCAPE
          if @applied
            @model.start_operation("Cancel Z-Scaling", true)
            @previous_entities.each { |e| e.erase! if e.valid? }
            @previous_entities = []
            @model.commit_operation
            @applied = false
          end
          @model.select_tool(nil)
        when 37, 39 # Left/Right arrow — adjust offset
          dir = key == 39 ? +1 : -1
          unless @arrow_key_dir == dir
            scroll_offset(dir)
            @arrow_key_dir  = dir
            @key_repeat_gen = (@key_repeat_gen || 0) + 1
            gen = @key_repeat_gen
            UI.start_timer(0.7, false) { key_repeat(dir, gen) }
          end
        when 40 # Down arrow — reset offset to zero
          apply(Sketchup.format_length(0))
        when 9 # Tab — cycle rotation mode
          before = @rotation_mode
          @rotation_mode = { ground: :flow, flow: :normal, normal: :ground }[@rotation_mode]
          puts "[OEZScaleTool.tab] #{before.inspect} → #{@rotation_mode.inspect}"
          rebuild_flow_map if @rotation_mode == :flow && @flow_map.empty?
          update_vcb
          apply(OEZScaleTool.last_offset_str)
        end
      end

      def onKeyUp(key, _repeat, flags, view)
        before_ctrl  = @mod_ctrl
        before_shift = @mod_shift
        case key
        when 17 then @mod_ctrl  = false
        when 16 then @mod_shift = false
        else
          @mod_ctrl  = flags & COPY_MODIFIER_MASK      != 0
          @mod_shift = flags & CONSTRAIN_MODIFIER_MASK != 0
        end
        key_name = { 16 => "Shift", 17 => "Ctrl", 27 => "Esc", 9 => "Tab", 37 => "Left", 38 => "Up", 39 => "Right", 40 => "Down" }[key] || "key#{key}"
        puts "[OEZScale.keyUp  ] #{key_name} flags=0x#{flags.to_s(16)}  ctrl:#{before_ctrl}→#{@mod_ctrl}  shift:#{before_shift}→#{@mod_shift}  sample:#{@sample_mode}"
        @arrow_key_dir = nil if key == 37 || key == 39
        update_cursor
        view.invalidate
      end

      private

      # SB_PROMPT=0, SB_VCB_LABEL=1, SB_VCB_VALUE=2
      def update_cursor
        variant = if @sample_mode
                    :pick
                  elsif @mod_ctrl && @mod_shift
                    :minus
                  elsif @mod_ctrl
                    :plus
                  elsif @mod_shift
                    :toggle
                  else
                    :default
                  end
        UI.set_cursor(OEZScaleTool.cursor_id(variant))
      end

      def pick_entity(view, x, y, aperture = 16)
        ph    = view.pick_helper
        count = ph.do_pick(x, y, aperture)
        paths = count.times.map { |i| ph.path_at(i) }

        placed = paths.find { |path| @entity_to_edge.key?(path.first) }
        return placed.first if placed

        root_edge = paths.find { |path| path.first.is_a?(Sketchup::Edge) && path.length == 1 }
        return root_edge.first if root_edge

        ph.best_picked
      end

      def pick_edges(view, x, y)
        entity = pick_entity(view, x, y, 16)
        entity = @entity_to_edge[entity] if entity && @entity_to_edge.key?(entity)
        pick_edges_from(entity)
      end

      def pick_edges_from(entity)
        case entity
        when Sketchup::Edge then [entity]
        when Sketchup::Face then entity.edges.to_a
        end
      end

      def connected_geometry(entity)
        start_edges = pick_edges_from(entity)
        return nil unless start_edges

        visited = {}
        queue   = start_edges.dup
        until queue.empty?
          edge = queue.pop
          next if visited[edge]
          visited[edge] = true
          [edge.start, edge.end].each do |v|
            v.edges.each { |e| queue << e unless visited[e] }
          end
          edge.faces.each do |f|
            f.edges.each { |e| queue << e unless visited[e] }
          end
        end
        visited.keys
      end

      def handle_click(flags, x, y, view, click_type)
        ctrl  = flags & COPY_MODIFIER_MASK      != 0
        shift = flags & CONSTRAIN_MODIFIER_MASK != 0

        best = pick_entity(view, x, y)
        best = @entity_to_edge[best] if best && @entity_to_edge.key?(best)

        if shift && best.is_a?(Sketchup::Edge)
          @drag_mode = :remove
          modify_edges(:remove, [best])
          return
        end

        picked_edges = case click_type
                       when :single then pick_edges_from(best)
                       when :double then connected_geometry(best)
                       end

        mode = if ctrl && shift
                 :remove
               elsif ctrl
                 :add
               elsif shift
                 picked_edges&.all? { |e| @edges.include?(e) } ? :remove : :add
               else
                 :replace
               end

        # Set drag_mode even when clicking empty space so subsequent drag picks up edges
        @drag_mode = mode unless mode == :replace

        return unless picked_edges

        modify_edges(mode, picked_edges)
      end

      def modify_edges(mode, picked_edges)
        before = @edges.to_set
        case mode
        when :add     then @edges = (@edges + picked_edges).uniq
        when :remove  then @edges = @edges - picked_edges
        when :replace then @edges = picked_edges.uniq
        end
        return if @edges.to_set == before
        rebuild_flow_map if @rotation_mode == :flow
        apply(OEZScaleTool.last_offset_str)
        sync_selection
      end

      def key_repeat(dir, gen)
        return unless @arrow_key_dir == dir && @key_repeat_gen == gen
        scroll_offset(dir)
        UI.start_timer(0.03, false) { key_repeat(dir, gen) }
      end

      def scroll_offset(direction)
        current = Sketchup.parse_length(OEZScaleTool.last_offset_str) rescue nil
        return unless current
        step    = Sketchup.parse_length("1cm")
        new_val = current + direction * step
        apply(Sketchup.format_length(new_val))
      end

      def on_external_selection_change
        return if @syncing
        return if @model.selection.empty?
        new_edges = (@model.selection.grep(Sketchup::Edge) +
                     @model.selection.grep(Sketchup::Face).flat_map(&:edges)).uniq.select(&:valid?)
        return if new_edges.to_set == @edges.to_set
        @edges = new_edges
        rebuild_flow_map if @rotation_mode == :flow
        @syncing = true
        apply(OEZScaleTool.last_offset_str)
        sync_selection
      ensure
        @syncing = false
      end

      def sync_selection
        valid_edges    = @edges.select(&:valid?)
        edge_set       = valid_edges.to_set
        full_faces     = valid_edges.flat_map(&:faces).uniq.select { |f|
          f.valid? && f.edges.all? { |e| edge_set.include?(e) }
        }
        valid_entities = @previous_entities.select(&:valid?)

        target  = (valid_edges + full_faces + valid_entities).to_set
        current = @model.selection.to_a.to_set

        to_remove = (current - target).to_a
        to_add    = (target - current).to_a

        @model.selection.remove(to_remove) unless to_remove.empty?
        @model.selection.add(to_add)       unless to_add.empty?
      end

      def rebuild_flow_map
        vertex_edges = {}
        @edges.each do |edge|
          [edge.start, edge.end].each do |v|
            vertex_edges[v] ||= []
            vertex_edges[v] << edge
          end
        end
        @flow_map = OrienterExpress.send(:all_vertex_flow_directions, vertex_edges)
      end

      def update_vcb
        mode_key = { ground: :rotation_ground, flow: :rotation_flow, normal: :rotation_normal }[@rotation_mode]
        mode = Lang.t(:html, :settings, mode_key)
        Sketchup.set_status_text(Lang.commands.oezscale.offset_prompt.to_s, 1)
        Sketchup.set_status_text(OEZScaleTool.last_offset_str, 2)
        Sketchup.set_status_text("#{Lang.commands.oezscale.vcb_hint}  |  #{mode}", 0)
      end

      def pick_new_sample(view, x, y)
        ph    = view.pick_helper
        count = ph.do_pick(x, y, 16)
        paths = count.times.map { |i| ph.path_at(i) }
        instance = paths.map(&:first).find { |e|
          e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
        }
        return unless instance
        @entity_def = instance.definition
        @entity_t   = instance.transformation
        @model.start_operation("Orienter Express: Change Sample", true, false, false)
        @previous_entities.each { |e| e.erase! if e.valid? }
        @previous_entities = []
        @model.commit_operation
        @entity_to_edge = {}
        @first_apply    = true
        @sample_mode    = false
        update_cursor
        apply(OEZScaleTool.last_offset_str)
        sync_selection
      end

      def apply(text)
        puts "[OEZScaleTool.apply] called with text=#{text.inspect} first=#{@first_apply} edges=#{@edges.size}"
        offset = begin
          Sketchup.parse_length(text)
        rescue => e
          puts "[OEZScaleTool.apply] parse_length failed: #{e.message}"
          nil
        end
        if offset.nil?
          puts "[OEZScaleTool.apply] offset nil, returning"
          return
        end
        puts "[OEZScaleTool.apply] offset=#{offset} transparent=#{!@first_apply}"

        transparent = !@first_apply
        @model.start_operation("Orienter Express: Z-Scaling", true, false, transparent)

        begin
          @previous_entities.each { |e| e.erase! if e.valid? }
          @previous_entities = []
          @entity_to_edge    = {}

          created = 0
          skipped = []
          @edges.each do |edge|
            next if edge.length.zero?
            effective_length = edge.length - 2 * offset
            if effective_length <= 1e-6
              puts "[OEZScaleTool.apply]   edge len=#{edge.length.round(3)} eff=#{effective_length.round(3)} SKIPPED"
              skipped << edge
              next
            end
            entity_copy = OrienterExpress.create_entity_copy(@entity_def, @entity_t)
            OrienterExpress.z_scale(entity_copy, edge, effective_length)
            OrienterExpress.orient_z(entity_copy, edge)
            case @rotation_mode
            when :flow
              OrienterExpress.send(:orient_to_flow, entity_copy, edge, @flow_map)
            when :normal
              OrienterExpress.send(:orient_to_face_normal, entity_copy, edge)
            else
              OrienterExpress.orient_x(entity_copy)
            end
            midpoint     = Geom::Point3d.linear_combination(
              0.5, edge.start.position, 0.5, edge.end.position)
            world_center = entity_copy.transformation * entity_copy.definition.bounds.center
            puts "[OEZScaleTool.apply]   midpoint=#{midpoint.to_a.map{|v|v.round(2)}} world_center=#{world_center.to_a.map{|v|v.round(2)}}"
            entity_copy.transform!(
              Geom::Transformation.translation(midpoint - world_center))
            @previous_entities << entity_copy
            @entity_to_edge[entity_copy] = edge
            created += 1
          end
          @model.commit_operation
          @first_apply      = false
          @applied          = true
          @skipped_edges    = skipped
          formatted = Sketchup.format_length(offset)
          OEZScaleTool.last_offset_str = formatted
          Sketchup.set_status_text(formatted, 2)
          @model.active_view.invalidate
          puts "[OEZScaleTool.apply] DONE created=#{created}"
        rescue => e
          @model.abort_operation
          puts "[OEZScaleTool.apply] ERROR #{e.class}: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
          UI.messagebox("Error: #{e.message}")
        end
      end
    end

    def self.oezscale
      model   = Sketchup.active_model
      edges   = (edges(model.selection) + faces(model.selection).flat_map(&:edges)).uniq
      targets = instances(model.selection)

      return unless check_targets(targets)

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
        OEZScaleTool.new(edges, entity.definition, entity.transformation,
                          flow_map, rotation_mode)
      )
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

      use_flow = CONFIG[:rotation_mode] == 'flow'
      flow_map = {}
      if use_flow
        vertex_edges = {}
        edges.each do |edge|
          [edge.start, edge.end].each do |v|
            vertex_edges[v] ||= []
            vertex_edges[v] << edge
          end
        end
        flow_map = all_vertex_flow_directions(vertex_edges)
      end

      op_name = "Orienter Express: Uniform Scaling"
      model.start_operation(op_name, true)
      Debug.log(self, method_id, "Process START")

      begin
        edges.each do |edge|
          next if edge.length.zero?
          entity_copy = create_entity_copy(entity_def, entity_t)
          uniform_scale(entity_copy, edge)
          orient_z(entity_copy, edge)
          use_flow ? orient_to_flow(entity_copy, edge, flow_map) : orient_x(entity_copy)
          midpoint = Geom::Point3d.linear_combination(0.5, edge.start.position, 0.5, edge.end.position)
          entity_copy.transform!(Geom::Transformation.translation(midpoint - entity_copy.bounds.center))
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

    # Tool class for interactive Flow Placement.
    # Places components at edge vertices aligned to the flow direction.
    # The user adjusts an offset along the flow direction via the VCB or arrow keys.
    class OEFlowTool
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

      def self.last_offset_str
        @@last_offset_str ||= CONFIG[:oeflow_offset] || "0cm"
      end

      def self.last_offset_str=(val)
        @@last_offset_str = val
        OrienterExpress.user_settings(oeflow_offset: val)
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

      def initialize(edges, entity_def, entity_t)
        @edges             = edges
        @entity_def        = entity_def
        @entity_t          = entity_t
        @model             = Sketchup.active_model
        @applied           = false
        @first_apply       = true
        @previous_entities = []
        @entity_to_vertex  = {}
        @insertion_point   = :base
        @sample_mode       = false
        @mod_ctrl          = false
        @mod_shift         = false
      end

      def activate
        @lbutton_down  = false
        @drag_mode     = nil
        @arrow_key_dir = nil
        @watcher = SelectionWatcher.new { on_external_selection_change }
        @model.selection.add_observer(@watcher)
        update_vcb
        UI.start_timer(0, false) { apply(OEFlowTool.last_offset_str); sync_selection }
      end

      def deactivate(view)
        @model.selection.remove_observer(@watcher) if @watcher
        @watcher           = nil
        @applied           = false
        @previous_entities = []
        @entity_to_vertex  = {}
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
        bb = Geom::BoundingBox.new
        @entity_def.bounds.corners.each { |c| bb.add(@entity_t * c) }
        bb
      end

      def draw(view)
        bounds  = @entity_def.bounds
        return if bounds.empty?
        eye     = view.camera.eye
        corners = 8.times.map do |i|
          pt = @entity_t * bounds.corner(i)
          pt.offset((eye - pt).normalize, 0.1)
        end
        pairs = [[0,1],[0,2],[1,3],[2,3],[4,5],[4,6],[5,7],[6,7],[0,4],[1,5],[2,6],[3,7]]
        view.line_width    = 3
        view.drawing_color = Sketchup::Color.new(255, 140, 0)
        pairs.each { |a, b| view.draw(GL_LINES, [corners[a], corners[b]]) }
      end

      def onLButtonDown(flags, x, y, view)
        if @sample_mode
          pick_new_sample(view, x, y)
          return
        end
        @lbutton_down = true
        @syncing = true
        saved = @edges.dup
        handle_click(flags, x, y, view, :single)
        @edges = saved if @edges.empty? && !saved.empty?
        sync_selection
      ensure
        @syncing = false
      end

      def onLButtonDoubleClick(flags, x, y, view)
        @syncing = true
        saved = @edges.dup
        handle_click(flags, x, y, view, :double)
        @edges = saved if @edges.empty? && !saved.empty?
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
          if ctrl || shift
            @sample_mode = false
          end
          update_cursor
          view.invalidate
        end
        if @lbutton_down && @drag_mode && (ctrl || shift)
          picked_edges = pick_edges(view, x, y)
          modify_edges(@drag_mode, picked_edges) if picked_edges
        end
      end

      def onUserText(text, _view)
        return if text.strip.empty?
        apply(text.strip)
      end

      def onKeyDown(key, _repeat, _flags, view)
        case key
        when 17 then @mod_ctrl = true;  @sample_mode = false; update_cursor; view.invalidate; return
        when 16 then @mod_shift = true; @sample_mode = false; update_cursor; view.invalidate; return
        end
        case key
        when 27 # VK_ESCAPE
          if @applied
            @model.start_operation("Cancel Flow Placement", true)
            @previous_entities.each { |e| e.erase! if e.valid? }
            @previous_entities = []
            @model.commit_operation
            @applied = false
          end
          @model.select_tool(nil)
        when 38 # Up arrow — toggle sample mode
          @sample_mode = !@sample_mode
          update_vcb
          update_cursor
          view.invalidate
        when 37, 39 # Left/Right arrow — adjust offset
          dir = key == 39 ? +1 : -1
          unless @arrow_key_dir == dir
            scroll_offset(dir)
            @arrow_key_dir  = dir
            @key_repeat_gen = (@key_repeat_gen || 0) + 1
            gen = @key_repeat_gen
            UI.start_timer(0.7, false) { key_repeat(dir, gen) }
          end
        when 40 # Down arrow — reset offset to zero
          apply(Sketchup.format_length(0))
        when 9 # Tab — cycle insertion point
          @insertion_point = { base: :center, center: :origin, origin: :base }[@insertion_point]
          update_vcb
          apply(OEFlowTool.last_offset_str)
        end
      end

      def onKeyUp(key, _repeat, _flags, view)
        case key
        when 17 then @mod_ctrl  = false; update_cursor; view.invalidate
        when 16 then @mod_shift = false; update_cursor; view.invalidate
        end
        @arrow_key_dir = nil if key == 37 || key == 39
      end

      def onSetCursor
        update_cursor
      end

      private

      def update_cursor
        variant = if @sample_mode
                    :pick
                  elsif @mod_ctrl && @mod_shift
                    :minus
                  elsif @mod_ctrl
                    :plus
                  elsif @mod_shift
                    :toggle
                  else
                    :default
                  end
        UI.set_cursor(OEFlowTool.cursor_id(variant))
      end

      def pick_entity(view, x, y, aperture = 16)
        ph    = view.pick_helper
        count = ph.do_pick(x, y, aperture)
        paths = count.times.map { |i| ph.path_at(i) }

        placed = paths.find { |path| @entity_to_vertex.key?(path.first) }
        return placed.first if placed

        root_edge = paths.find { |path| path.first.is_a?(Sketchup::Edge) && path.length == 1 }
        return root_edge.first if root_edge

        ph.best_picked
      end

      def pick_edges(view, x, y)
        entity = pick_entity(view, x, y)
        pick_edges_from(entity)
      end

      def pick_edges_from(entity)
        case entity
        when Sketchup::Edge then [entity]
        when Sketchup::Face then entity.edges.to_a
        end
      end

      def connected_geometry(entity)
        start_edges = pick_edges_from(entity)
        return nil unless start_edges

        visited = {}
        queue   = start_edges.dup
        until queue.empty?
          edge = queue.pop
          next if visited[edge]
          visited[edge] = true
          [edge.start, edge.end].each do |v|
            v.edges.each { |e| queue << e unless visited[e] }
          end
          edge.faces.each do |f|
            f.edges.each { |e| queue << e unless visited[e] }
          end
        end
        visited.keys
      end

      def handle_click(flags, x, y, view, click_type)
        ctrl  = flags & COPY_MODIFIER_MASK      != 0
        shift = flags & CONSTRAIN_MODIFIER_MASK != 0

        best = pick_entity(view, x, y)

        picked_edges = case click_type
                       when :single then pick_edges_from(best)
                       when :double then connected_geometry(best)
                       end

        mode = if ctrl && shift
                 :remove
               elsif ctrl
                 :add
               elsif shift
                 picked_edges&.all? { |e| @edges.include?(e) } ? :remove : :add
               else
                 :replace
               end

        @drag_mode = mode unless mode == :replace
        return unless picked_edges

        modify_edges(mode, picked_edges)
      end

      def modify_edges(mode, picked_edges)
        before = @edges.to_set
        case mode
        when :add     then @edges = (@edges + picked_edges).uniq
        when :remove  then @edges = @edges - picked_edges
        when :replace then @edges = picked_edges.uniq
        end
        return if @edges.to_set == before
        apply(OEFlowTool.last_offset_str)
        sync_selection
      end

      def key_repeat(dir, gen)
        return unless @arrow_key_dir == dir && @key_repeat_gen == gen
        scroll_offset(dir)
        UI.start_timer(0.03, false) { key_repeat(dir, gen) }
      end

      def scroll_offset(direction)
        current = Sketchup.parse_length(OEFlowTool.last_offset_str) rescue nil
        return unless current
        step    = Sketchup.parse_length("1cm")
        apply(Sketchup.format_length(current + direction * step))
      end

      def on_external_selection_change
        return if @syncing
        return if @model.selection.empty?
        new_edges = (@model.selection.grep(Sketchup::Edge) +
                     @model.selection.grep(Sketchup::Face).flat_map(&:edges)).uniq.select(&:valid?)
        return if new_edges.empty?
        return if new_edges.to_set == @edges.to_set
        @edges = new_edges
        @syncing = true
        apply(OEFlowTool.last_offset_str)
        sync_selection
      ensure
        @syncing = false
      end

      def pick_new_sample(view, x, y)
        ph    = view.pick_helper
        count = ph.do_pick(x, y, 16)
        paths = count.times.map { |i| ph.path_at(i) }
        instance = paths.map(&:first).find { |e|
          e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
        }
        return unless instance
        @entity_def = instance.definition
        @entity_t   = instance.transformation
        @model.start_operation("Orienter Express: Change Sample", true, false, false)
        @previous_entities.each { |e| e.erase! if e.valid? }
        @previous_entities = []
        @model.commit_operation
        @entity_to_vertex = {}
        @first_apply      = true
        @sample_mode      = false
        update_vcb
        apply(OEFlowTool.last_offset_str)
        sync_selection
      end

      def sync_selection
        valid_edges    = @edges.select(&:valid?)
        valid_entities = @previous_entities.select(&:valid?)
        target  = (valid_edges + valid_entities).to_set
        current = @model.selection.to_a.to_set
        to_remove = (current - target).to_a
        to_add    = (target - current).to_a
        @model.selection.remove(to_remove) unless to_remove.empty?
        @model.selection.add(to_add)       unless to_add.empty?
      end

      def update_vcb
        ip_key = { base: :insertion_base_short, center: :insertion_center_short, origin: :insertion_origin_short }[@insertion_point]
        ip = Lang.t(:html, :settings, ip_key)
        Sketchup.set_status_text(Lang.commands.oeflow.offset_prompt.to_s, 1)
        Sketchup.set_status_text(OEFlowTool.last_offset_str, 2)
        sample_label = @sample_mode ? "  [SAMPLE]" : ""
        Sketchup.set_status_text("#{Lang.commands.oeflow.vcb_hint}  |  #{ip}#{sample_label}", 0)
      end

      def apply(text)
        offset = Sketchup.parse_length(text) rescue nil
        return unless offset

        vertex_edges = {}
        @edges.select(&:valid?).each do |edge|
          [edge.start, edge.end].each do |v|
            vertex_edges[v] ||= []
            vertex_edges[v] << edge
          end
        end
        flow_map = OrienterExpress.send(:all_vertex_flow_directions, vertex_edges)

        transparent = !@first_apply
        @model.start_operation("Orienter Express: Flow Placement", true, false, transparent)

        begin
          @previous_entities.each { |e| e.erase! if e.valid? }
          @previous_entities = []
          @entity_to_vertex  = {}

          flow_map.each do |vertex, direction|
            target      = vertex.position.offset(direction.normalize, offset)
            entity_copy = OrienterExpress.create_entity_copy(@entity_def, @entity_t)
            t           = entity_copy.transformation
            OrienterExpress.send(:align_axis, entity_copy, t.origin, t.zaxis, direction)
            OrienterExpress.orient_x(entity_copy)
            entity_ref = case @insertion_point
                         when :origin
                           entity_copy.transformation.origin
                         when :base
                           db = entity_copy.definition.bounds
                           entity_copy.transformation * Geom::Point3d.new(db.center.x, db.center.y, db.min.z)
                         else # :center
                           entity_copy.bounds.center
                         end
            entity_copy.transform!(Geom::Transformation.translation(target - entity_ref))
            @previous_entities << entity_copy
            @entity_to_vertex[entity_copy] = vertex
          end

          @model.commit_operation
          @first_apply = false
          @applied     = true
          formatted = Sketchup.format_length(offset)
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

      return unless check_targets(targets)

      entity = targets.first
      model.select_tool(
        OEFlowTool.new(edges, entity.definition, entity.transformation)
      )
    end

    # Tool class for interactive Face Placement.
    # Equivalent to OEZScaleTool but for faces: the user adjusts an offset
    # along the face normal via the VCB or arrow keys.
    class OEFaceTool
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

      def self.last_offset_str
        @@last_offset_str ||= CONFIG[:oeface_offset] || "0cm"
      end

      def self.last_offset_str=(val)
        @@last_offset_str = val
        OrienterExpress.user_settings(oeface_offset: val)
      end

      def self.cursor_id(variant = :default)
        @@cursor_ids ||= {}
        @@cursor_ids[variant] ||= begin
          ext      = Sketchup.platform == :platform_win ? 'svg' : 'pdf'
          filename = variant == :default ? "oeface_32" : "oeface_#{variant}_32"
          path     = File.join(PATH_CURSORS, "#{filename}.#{ext}")
          UI.create_cursor(path, 5, 5)
        end
      end

      def initialize(faces, entity_def, entity_t)
        @faces             = faces
        @entity_def        = entity_def
        @entity_t          = entity_t
        @model             = Sketchup.active_model
        @applied           = false
        @first_apply       = true
        @previous_entities = []
        @entity_to_face    = {}
        @insertion_point   = :base
        @axis_idx          = 0
        @sample_mode       = false
        @mod_ctrl          = false
        @mod_shift         = false
      end

      def activate
        @lbutton_down  = false
        @drag_mode     = nil
        @arrow_key_dir = nil
        @watcher = SelectionWatcher.new { on_external_selection_change }
        @model.selection.add_observer(@watcher)
        update_vcb
        UI.start_timer(0, false) { apply(OEFaceTool.last_offset_str); sync_selection }
      end

      def deactivate(view)
        @model.selection.remove_observer(@watcher) if @watcher
        @watcher           = nil
        @applied           = false
        @previous_entities = []
        @entity_to_face    = {}
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
        bb = Geom::BoundingBox.new
        @entity_def.bounds.corners.each { |c| bb.add(@entity_t * c) }
        bb
      end

      def draw(view)
        draw_bounds(view, @entity_def.bounds, @entity_t,
                    Sketchup::Color.new(255, 140, 0), 3)
      end

      def onLButtonDown(flags, x, y, view)
        if @sample_mode
          pick_new_sample(view, x, y)
          return
        end
        @lbutton_down = true
        @syncing = true
        saved = @faces.dup
        handle_click(flags, x, y, view, :single)
        @faces = saved if @faces.empty? && !saved.empty?
        sync_selection
      ensure
        @syncing = false
      end

      def onLButtonDoubleClick(flags, x, y, view)
        @syncing = true
        saved = @faces.dup
        handle_click(flags, x, y, view, :double)
        @faces = saved if @faces.empty? && !saved.empty?
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
        end
        if @lbutton_down && @drag_mode && (ctrl || shift)
          picked_faces = pick_faces(view, x, y)
          modify_faces(@drag_mode, picked_faces) if picked_faces
        end
      end

      def onUserText(text, _view)
        return if text.strip.empty?
        apply(text.strip)
      end

      def onKeyDown(key, _repeat, _flags, view)
        case key
        when 17 then @mod_ctrl = true;  @sample_mode = false; update_cursor; view.invalidate; return
        when 16 then @mod_shift = true; @sample_mode = false; update_cursor; view.invalidate; return
        end
        case key
        when 27 # VK_ESCAPE
          if @applied
            @model.start_operation("Cancel Face Placement", true)
            @previous_entities.each { |e| e.erase! if e.valid? }
            @previous_entities = []
            @model.commit_operation
            @applied = false
          end
          @model.select_tool(nil)
        when 9 # Tab — cycle insertion point
          @insertion_point = { base: :center, center: :origin, origin: :base }[@insertion_point]
          update_vcb
          apply(OEFaceTool.last_offset_str)
        when 37, 39 # Left/Right arrow — adjust offset
          dir = key == 39 ? +1 : -1
          unless @arrow_key_dir == dir
            scroll_offset(dir)
            @arrow_key_dir  = dir
            @key_repeat_gen = (@key_repeat_gen || 0) + 1
            gen = @key_repeat_gen
            UI.start_timer(0.7, false) { key_repeat(dir, gen) }
          end
        when 38 # Up arrow — toggle sample mode
          @sample_mode = !@sample_mode
          update_vcb
          update_cursor
          view.invalidate
        when 36 # Home — cycle face orientation mode
          @axis_idx = (@axis_idx + 1) % 3
          update_vcb
          apply(OEFaceTool.last_offset_str)
        when 40 # Down arrow — reset offset to zero
          apply(Sketchup.format_length(0))
        end
      end

      def onKeyUp(key, _repeat, _flags, view)
        case key
        when 17 then @mod_ctrl  = false; update_cursor; view.invalidate
        when 16 then @mod_shift = false; update_cursor; view.invalidate
        end
        @arrow_key_dir = nil if key == 37 || key == 39
      end

      def onSetCursor
        update_cursor
      end

      private

      def update_cursor
        variant = if @sample_mode
                    :pick
                  elsif @mod_ctrl && @mod_shift
                    :minus
                  elsif @mod_ctrl
                    :plus
                  elsif @mod_shift
                    :toggle
                  else
                    :default
                  end
        UI.set_cursor(OEFaceTool.cursor_id(variant))
      end

      def pick_faces(view, x, y)
        ph = view.pick_helper
        ph.do_pick(x, y)
        pick_faces_from(ph.best_picked)
      end

      def pick_faces_from(entity)
        case entity
        when Sketchup::Face then [entity]
        when Sketchup::Edge then entity.faces.to_a
        end
      end

      def connected_geometry(entity)
        start_faces = pick_faces_from(entity)
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

      def handle_click(flags, x, y, view, click_type)
        ctrl  = flags & COPY_MODIFIER_MASK      != 0
        shift = flags & CONSTRAIN_MODIFIER_MASK != 0

        ph = view.pick_helper
        ph.do_pick(x, y)
        best = ph.best_picked

        if shift && best && @entity_to_face.key?(best)
          @drag_mode = :remove
          modify_faces(:remove, [@entity_to_face[best]])
          return
        end

        best = @entity_to_face[best] if best && @entity_to_face.key?(best)

        picked_faces = case click_type
                       when :single then pick_faces_from(best)
                       when :double then connected_geometry(best)
                       end

        if ctrl && shift
          @drag_mode = :remove
        elsif ctrl
          @drag_mode = :add
        elsif shift
          @drag_mode = :add
        end

        return unless picked_faces

        mode = if ctrl && shift
                 :remove
               elsif ctrl
                 :add
               elsif shift
                 picked_faces.all? { |f| @faces.include?(f) } ? :remove : :add
               else
                 :replace
               end

        @drag_mode = mode unless mode == :replace
        modify_faces(mode, picked_faces)
      end

      def modify_faces(mode, picked_faces)
        before = @faces.to_set
        case mode
        when :add     then @faces = (@faces + picked_faces).uniq
        when :remove  then @faces = @faces - picked_faces
        when :replace then @faces = picked_faces.uniq
        end
        return if @faces.to_set == before
        apply(OEFaceTool.last_offset_str)
        sync_selection
      end

      def key_repeat(dir, gen)
        return unless @arrow_key_dir == dir && @key_repeat_gen == gen
        scroll_offset(dir)
        UI.start_timer(0.03, false) { key_repeat(dir, gen) }
      end

      def scroll_offset(direction)
        current = Sketchup.parse_length(OEFaceTool.last_offset_str) rescue nil
        return unless current
        step    = Sketchup.parse_length("1cm")
        apply(Sketchup.format_length(current + direction * step))
      end

      def on_external_selection_change
        return if @syncing
        return if @model.selection.empty?
        new_faces = (@model.selection.grep(Sketchup::Face) +
                     @model.selection.grep(Sketchup::Edge).flat_map(&:faces)).uniq.select(&:valid?)
        return if new_faces.empty?
        return if new_faces.to_set == @faces.to_set
        @faces = new_faces
        @syncing = true
        apply(OEFaceTool.last_offset_str)
        sync_selection
      ensure
        @syncing = false
      end

      def sync_selection
        valid_faces  = @faces.select(&:valid?)
        valid_placed = @previous_entities.select(&:valid?)

        target  = (valid_faces + valid_placed).to_set
        current = @model.selection.to_a.to_set

        to_remove = (current - target).to_a
        to_add    = (target - current).to_a

        @model.selection.remove(to_remove) unless to_remove.empty?
        @model.selection.add(to_add)       unless to_add.empty?
      end

      def update_vcb
        ip_key = { base: :insertion_base_short, center: :insertion_center_short, origin: :insertion_origin_short }[@insertion_point]
        ip = Lang.t(:html, :settings, ip_key)
        Sketchup.set_status_text(Lang.commands.oeface.offset_prompt.to_s, 1)
        Sketchup.set_status_text(OEFaceTool.last_offset_str, 2)
        axis_label   = [
          Lang.commands.oeface.axis_parallel,
          Lang.commands.oeface.axis_perp,
          Lang.commands.oeface.axis_ground
        ][@axis_idx]
        sample_label = @sample_mode ? "  [SAMPLE]" : ""
        Sketchup.set_status_text("#{Lang.commands.oeface.vcb_hint}  |  #{ip}  |  #{axis_label}  [Home]#{sample_label}", 0)
      end

      def apply(text)
        offset = Sketchup.parse_length(text) rescue nil
        return unless offset

        transparent = !@first_apply
        @model.start_operation("Orienter Express: Face Placement", true, false, transparent)

        begin
          @previous_entities.each { |e| e.erase! if e.valid? }
          @previous_entities = []
          @entity_to_face    = {}

          @faces.each do |face|
            next unless face.valid?
            normal = face.normal
            next if normal.length < 1e-6
            centroid    = OrienterExpress.send(:face_centroid, face)
            target      = centroid.offset(normal.normalize, offset)
            entity_copy = OrienterExpress.create_entity_copy(@entity_def, @entity_t)
            t           = entity_copy.transformation
            OrienterExpress.align_axis(entity_copy, t.origin, t.zaxis, normal)
            if @axis_idx == 2
              OrienterExpress.orient_x(entity_copy)
            else
              OrienterExpress.orient_to_face_edge(entity_copy, face, @axis_idx)
            end
            entity_ref = case @insertion_point
                         when :origin
                           entity_copy.transformation.origin
                         when :base
                           db = entity_copy.definition.bounds
                           entity_copy.transformation * Geom::Point3d.new(db.center.x, db.center.y, db.min.z)
                         else # :center
                           entity_copy.bounds.center
                         end
            entity_copy.transform!(Geom::Transformation.translation(target - entity_ref))
            @previous_entities << entity_copy
            @entity_to_face[entity_copy] = face
          end
          @model.commit_operation
          @first_apply = false
          @applied     = true
          formatted = Sketchup.format_length(offset)
          OEFaceTool.last_offset_str = formatted
          Sketchup.set_status_text(formatted, 2)
          @model.active_view.invalidate
        rescue => e
          @model.abort_operation
          UI.messagebox("Error: #{e.message}")
        end
      end

      def draw_bounds(view, bounds, transformation, color, line_width)
        return if bounds.empty?
        eye     = view.camera.eye
        corners = 8.times.map do |i|
          pt = transformation * bounds.corner(i)
          pt.offset((eye - pt).normalize, 0.1)
        end
        pairs = [[0,1],[0,2],[1,3],[2,3],[4,5],[4,6],[5,7],[6,7],[0,4],[1,5],[2,6],[3,7]]
        view.line_width    = line_width
        view.drawing_color = color
        pairs.each { |a, b| view.draw(GL_LINES, [corners[a], corners[b]]) }
      end

      def pick_new_sample(view, x, y)
        ph    = view.pick_helper
        count = ph.do_pick(x, y, 16)
        paths = count.times.map { |i| ph.path_at(i) }
        instance = paths.map(&:first).find { |e|
          e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
        }
        return unless instance
        @entity_def = instance.definition
        @entity_t   = instance.transformation
        @model.start_operation("Orienter Express: Change Sample", true, false, false)
        @previous_entities.each { |e| e.erase! if e.valid? }
        @previous_entities = []
        @model.commit_operation
        @entity_to_face = {}
        @first_apply    = true
        @sample_mode    = false
        update_vcb
        apply(OEFaceTool.last_offset_str)
        sync_selection
      end
    end

    def self.oeface
      model   = Sketchup.active_model
      faces   = (faces(model.selection) + edges(model.selection).flat_map(&:faces)).uniq
      targets = instances(model.selection)

      return unless check_targets(targets)

      entity = targets.first
      model.select_tool(
        OEFaceTool.new(faces, entity.definition, entity.transformation)
      )
    end

    ### EXTRA TOOLS ### -----------------------------------------------------------

    # Tool class for interactive Reset Rotations.
    # Tab cycles the pivot point; the reset is re-applied live on each change.
    class OEResetTool
      def initialize(targets)
        @targets        = targets
        @original_ts    = targets.map(&:transformation)
        @model          = Sketchup.active_model
        @applied         = false
        @first_apply     = true
        custom = CONFIG[:insertion_point_custom]
        @insertion_point = (custom.is_a?(Hash) && custom[:oereset] ? custom[:oereset].to_sym : :base)
      end

      def activate
        update_vcb
        UI.start_timer(0, false) { apply }
      end

      def deactivate(_view)
        @applied = false
      end

      def resume(_view)
        update_vcb
      end

      def onKeyDown(key, _repeat, _flags, _view)
        case key
        when 27 # Esc — undo and exit
          if @applied
            @model.start_operation("Cancel Reset Rotations", true)
            @targets.each_with_index { |e, i| e.transformation = @original_ts[i] if e.valid? }
            @model.commit_operation
            @applied = false
          end
          @model.select_tool(nil)
        when 9 # Tab — cycle pivot
          @insertion_point = { center: :origin, origin: :base, base: :center }[@insertion_point]
          custom = CONFIG[:insertion_point_custom] || {}
          OrienterExpress.user_settings(insertion_point_custom: custom.merge(oereset: @insertion_point.to_s))
          update_vcb
          apply
        end
      end

      private

      def pivot_for(entity)
        case @insertion_point
        when :origin
          entity.transformation.origin
        when :base
          db = entity.definition.bounds
          entity.transformation * Geom::Point3d.new(db.center.x, db.center.y, db.min.z)
        else # :center
          entity.bounds.center
        end
      end

      def update_vcb
        ip_key = { base: :insertion_base_short, center: :insertion_center_short, origin: :insertion_origin_short }[@insertion_point]
        ip = Lang.t(:html, :settings, ip_key)
        Sketchup.set_status_text("#{Lang.commands.oereset.vcb_hint}  |  #{ip}", 0)
      end

      def apply
        transparent = !@first_apply
        @model.start_operation("Orienter Express: Reset Rotations", true, false, transparent)
        begin
          @targets.each_with_index do |entity, i|
            next unless entity.valid?
            entity.transformation = @original_ts[i]
            pivot = pivot_for(entity)
            OrienterExpress.send(:align_axis, entity, pivot, entity.transformation.zaxis, Z_AXIS)
            OrienterExpress.send(:align_axis, entity, pivot, entity.transformation.xaxis, X_AXIS)
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

    def self.oereset
      model   = Sketchup.active_model
      targets = instances(model.selection)
      return unless check_targets(targets)
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

    # Returns the subset of pts that form the 3D convex hull (QuickHull algorithm).
    # Guarantees no extreme point is lost, which is required for exact BB computation.
    def self.convex_hull_3d(pts)
      return pts if pts.size <= 4

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
      return pts unless i2
      i3 = (0...pts.size).reject{|i|[i0,i1,i2].include?(i)}.max_by { |i|
        sd.call(i0,i1,i2, pts[i]).abs
      }
      return pts if i3.nil? || sd.call(i0,i1,i2, pts[i3]).abs < eps

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

      faces.compact.flatten.uniq.map { |i| pts[i] }
    end

    # BB volume of pts after XY rotation by angle around [0,0,1] through origin.
    def self.bb_vol_at_angle(pts, angle)
      cos_a = Math.cos(angle)
      sin_a = Math.sin(angle)
      xs, ys, zs = [], [], []
      pts.each do |p|
        xs << p.x * cos_a - p.y * sin_a
        ys << p.x * sin_a + p.y * cos_a
        zs << p.z
      end
      return Float::INFINITY if xs.empty?
      (xs.max - xs.min) * (ys.max - ys.min) * (zs.max - zs.min)
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
      puts "[OEAlignPCA] scale baked: (#{sx.round(4)}, #{sy.round(4)}, #{sz.round(4)})"
    end

    # Redefines the local axes so that local X aligns with the dominant edge,
    # chosen by minimum bounding box volume. Geometry stays in world position.
    #
    # Strategy:
    #   1. Extract rotation part of t → r_reset (maps def-local to world-aligned frame)
    #   2. Virtually apply r_reset to all vertices → world-aligned frame where local Z = world Z
    #   3. Find best XY rotation angle in that frame using edge candidates + BB volume
    #   4. Compose: r_combined = r_best * r_reset (applied to geometry)
    #   5. Compensate all instances: T_new = T_old * r_combined_inv
    #      → world positions preserved, local X now points along dominant edge
    def self.align_x_to_dominant_edge(instance)
      instance.make_unique if instance.is_a?(Sketchup::Group) && instance.definition.instances.size > 1
      bake_scale(instance)
      t = instance.transformation
      a  = t.to_a
      sx = Math.sqrt(a[0]**2 + a[1]**2 + a[2]**2)
      sy = Math.sqrt(a[4]**2 + a[5]**2 + a[6]**2)
      sz = Math.sqrt(a[8]**2 + a[9]**2 + a[10]**2)

      # r_reset = rotation part of t (maps def-local → world-aligned, no translation).
      # For LH instances det(r_reset) = -1; negate Y column to get a proper rotation
      # so that r_combined = r_best * r_reset has det=+1 and handedness is preserved.
      det_sign = (a[0]/sx * (a[5]/sy * a[10]/sz - a[6]/sy * a[9]/sz)) -
                 (a[1]/sx * (a[4]/sy * a[10]/sz - a[6]/sy * a[8]/sz)) +
                 (a[2]/sx * (a[4]/sy * a[9]/sz  - a[5]/sy * a[8]/sz)) >= 0 ? 1 : -1
      r_reset = Geom::Transformation.new([
        a[0]/sx,            a[1]/sx,            a[2]/sx,            0,
        a[4]/sy * det_sign, a[5]/sy * det_sign, a[6]/sy * det_sign, 0,
        a[8]/sz,            a[9]/sz,            a[10]/sz,           0,
        0, 0, 0, 1
      ])
      r_reset_inv = r_reset.inverse

      # Vertices in world-aligned frame
      pts_reset = collect_vertices(instance.definition.entities, r_reset)
      puts "[OEAlignX] instance=#{instance.definition.name} pts=#{pts_reset.size}"
      return if pts_reset.empty?

      # bb_vol_at_angle has period 90° (swapping X/Y extents preserves product),
      # so we only need to search [0°, 90°).
      # Phase 1: coarse sweep every 2° over [0°, 88°]
      deg2rad = Math::PI / 180.0
      coarse_best_angle = 0.0
      coarse_best_vol   = bb_vol_at_angle(pts_reset, 0.0)
      puts "[OEAlignX] current vol=#{coarse_best_vol.round(4)}"
      (2...90).step(2) do |deg|
        a2  = deg * deg2rad
        vol = bb_vol_at_angle(pts_reset, a2)
        if vol < coarse_best_vol
          coarse_best_vol   = vol
          coarse_best_angle = a2
        end
      end
      puts "[OEAlignX] coarse best=#{(coarse_best_angle/deg2rad).round(1)}° vol=#{coarse_best_vol.round(4)}"

      # Phase 2: fine sweep ±2° around coarse minimum in 0.1° steps
      best_angle = nil
      best_vol   = bb_vol_at_angle(pts_reset, 0.0)
      lo = coarse_best_angle - 2.0 * deg2rad
      hi = coarse_best_angle + 2.0 * deg2rad
      (lo..hi).step(0.1 * deg2rad) do |a2|
        vol = bb_vol_at_angle(pts_reset, a2)
        if vol < best_vol - 1e-4
          best_vol   = vol
          best_angle = a2
        end
      end

      if best_angle.nil?
        puts "[OEAlignX] already optimal"
        return
      end
      puts "[OEAlignX] best=#{(best_angle/deg2rad).round(2)}° vol=#{best_vol.round(4)}"

      local_origin = Geom::Point3d.new(0, 0, 0)
      world_z      = Geom::Vector3d.new(0, 0, 1)
      r_best     = Geom::Transformation.rotation(local_origin, world_z,  best_angle)
      r_best_inv = Geom::Transformation.rotation(local_origin, world_z, -best_angle)

      # r_combined = r_best * r_reset  (applied to geometry)
      # r_combined_inv = r_reset_inv * r_best_inv  (post-multiplied to instances)
      r_combined     = r_best     * r_reset
      r_combined_inv = r_reset_inv * r_best_inv

      instance.definition.entities.transform_entities(r_combined, instance.definition.entities.to_a)
      instance.definition.instances.each do |inst|
        before = inst.transformation.origin
        inst.transformation = inst.transformation * r_combined_inv
        after  = inst.transformation.origin
        puts "[OEAlignX]   origin: #{before.to_a.map{|v|v.round(3)}} → #{after.to_a.map{|v|v.round(3)}}"
      end
      puts "[OEAlignX] done"
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

    # Permutes and/or flips local axes so that:
    # 1. X has the largest BB extent, Y medium, Z smallest (primary, weight ×100).
    # 2. Among tied extents (within 0.5% relative), axes align as well as possible
    #    with world axes (secondary, weight 1).
    # Searches all 24 proper rotations of the cube (6 permutations × 4 right-handed
    # sign combinations). Must be called after geometry is in definition space.
    def self.permute_axes_by_extent(instance)
      pts = collect_vertices(instance.definition.entities, Geom::Transformation.new)
      return if pts.empty?

      xs = pts.map(&:x); ys = pts.map(&:y); zs = pts.map(&:z)
      dx = xs.max - xs.min; dy = ys.max - ys.min; dz = zs.max - zs.min

      mean_ext = (dx + dy + dz) / 3.0
      tol      = [mean_ext * 5e-3, 1e-6].max
      buckets  = [dx, dy, dz].map { |e| (e / tol).round }

      t        = instance.transformation
      inst_det = t.xaxis.dot(t.yaxis.cross(t.zaxis)) >= 0 ? 1 : -1
      # For LH instances negate X before scoring so the search sees the
      # "equivalent RH" axes → same permutation+signs as the RH counterpart.
      # Proper rotations (det=+1) are used regardless, so handedness is preserved.
      ax = inst_det < 0 ? Geom::Vector3d.new(-t.xaxis.x, -t.xaxis.y, -t.xaxis.z) : t.xaxis
      axes = [ax, t.yaxis, t.zaxis]

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
          ext_score  = (buckets[perm[0]] >= buckets[perm[1]] ? 100 : -100)
          ext_score += (buckets[perm[1]] >= buckets[perm[2]] ? 100 : -100)
          align      = sx * axes[perm[0]].x + sy * axes[perm[1]].y + sz * axes[perm[2]].z
          score      = ext_score + align
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
      puts "[OEAlignPCA] axes normalized: perm=#{best_perm} signs=(#{best_signs.join(',')})"
    end

    # Redefines the local axes to minimize the bounding box volume (3D) or area
    # (2D flat geometry). Uses a two-phase ZYZ Euler sweep + Nelder-Mead for 3D,
    # or normal alignment + 1D sweep for flat/planar geometry.
    # Geometry stays in world position.
    def self.align_to_min_bb(instance)
      # Work in definition space (identity frame). This makes the algorithm
      # idempotent: after applying, the next call sees already-rotated pts
      # and the sweep returns identity → no further change.
      id = Geom::Transformation.new
      pts = collect_vertices(instance.definition.entities, id)
      t0  = instance.transformation
      det0 = t0.xaxis.dot(t0.yaxis.cross(t0.zaxis)) >= 0 ? "RH" : "LH"
      puts "[OEAlignPCA] instance=#{instance.definition.name} pts=#{pts.size} handedness=#{det0}"
      return if pts.empty?

      pts = convex_hull_3d(pts)
      puts "[OEAlignPCA] hull pts=#{pts.size}"

      deg2rad = Math::PI / 180.0

      # ── 2D path: flat/planar geometry ──────────────────────────────────────
      normal = planar_normal(pts)
      if normal
        nx, ny, nz = normal
        puts "[OEAlignPCA] planar geometry, normal=[#{nx.round(4)},#{ny.round(4)},#{nz.round(4)}]"

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
        puts "[OEAlignPCA] 2D rotating-calipers best=#{(fine_angle/deg2rad).round(3)}° area=#{fine_area.round(4)} (#{edge_angles.size} edges)"

        # Compose r1 (normal align) + r2 (in-plane rotation)
        flat_axis_vec = Geom::Vector3d.new(*axes[axis_idx])
        r2      = Geom::Transformation.rotation(orig, flat_axis_vec, fine_angle)
        r_total = r2 * r1

        # Skip if total rotation is negligible (< 0.006°)
        m = r_total.to_a
        trace = m[0] + m[5] + m[10]
        total_angle = Math.acos([[(trace - 1.0) / 2.0, -1.0].max, 1.0].min)
        if total_angle < 1e-4
          puts "[OEAlignPCA] already optimal (2D)"
          return
        end

        r_total_inv = r_total.inverse
        instance.definition.entities.transform_entities(r_total, instance.definition.entities.to_a)
        instance.definition.instances.each do |inst|
          before = inst.transformation.origin
          inst.transformation = inst.transformation * r_total_inv
          after  = inst.transformation.origin
          puts "[OEAlignPCA]   origin: #{before.to_a.map{|v|v.round(3)}} → #{after.to_a.map{|v|v.round(3)}}"
        end
        permute_axes_by_extent(instance)
        t1 = instance.transformation
        det1 = t1.xaxis.dot(t1.yaxis.cross(t1.zaxis)) >= 0 ? "RH" : "LH"
        puts "[OEAlignPCA] done (2D) handedness=#{det1}"
        return
      end

      # ── 3D path: ZYZ Euler sweep + Nelder-Mead ─────────────────────────────
      # ZYZ Euler angles: R = Rz(α) * Ry(β) * Rz(γ)
      # Matrix rows:
      #   [ca*cb*cg - sa*sg,  -ca*cb*sg - sa*cg,  ca*sb]
      #   [sa*cb*cg + ca*sg,  -sa*cb*sg + ca*cg,  sa*sb]
      #   [-sb*cg,             sb*sg,              cb   ]
      # BB has 90° period in α and γ → search [0°,90°) × [-90°,90°) × [0°,90°)
      deg2rad = Math::PI / 180.0

      eval_zyz = lambda do |al, be, ga|
        ca = Math.cos(al); sa = Math.sin(al)
        cb = Math.cos(be); sb = Math.sin(be)
        cg = Math.cos(ga); sg = Math.sin(ga)
        bb_vol_3d(pts,
          ca*cb*cg - sa*sg,  -ca*cb*sg - sa*cg,  ca*sb,
          sa*cb*cg + ca*sg,  -sa*cb*sg + ca*cg,  sa*sb,
          -sb*cg,             sb*sg,              cb)
      end

      # Phase 1: coarse grid 10° → 9×18×9 = 1,458 evals to find basin
      best_al = 0.0; best_be = 0.0; best_ga = 0.0
      best_vol = Float::INFINITY
      (0...90).step(10) do |ad|
        (-90...90).step(10) do |bd|
          (0...90).step(10) do |gd|
            vol = eval_zyz.call(ad*deg2rad, bd*deg2rad, gd*deg2rad)
            if vol < best_vol
              best_vol = vol; best_al = ad*deg2rad; best_be = bd*deg2rad; best_ga = gd*deg2rad
            end
          end
        end
      end
      puts "[OEAlignPCA] coarse best=α#{(best_al/deg2rad).round(1)}° β#{(best_be/deg2rad).round(1)}° γ#{(best_ga/deg2rad).round(1)}° vol=#{best_vol.round(4)}"

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

      200.times do
        # Sort by function value
        order = fval.each_with_index.sort_by { |f, _| f }.map(&:last)
        simplex = order.map { |i| simplex[i] }
        fval    = order.map { |i| fval[i] }

        break if (fval.last - fval.first).abs < 1e-6

        # Centroid of all but worst
        c = [0.0, 0.0, 0.0]
        3.times { |i| 3.times { |d| c[d] += simplex[i][d] / 3.0 } }

        worst = simplex[3]; fw = fval[3]

        # Reflection
        xr  = c.each_with_index.map { |ci, d| 2*ci - worst[d] }
        fxr = eval_zyz.call(*xr)

        if fxr < fval[0]
          # Expansion
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
          # Contraction
          xc  = c.each_with_index.map { |ci, d| 0.5*(ci + worst[d]) }
          fxc = eval_zyz.call(*xc)
          if fxc < fw
            simplex[3] = xc; fval[3] = fxc
          else
            # Shrink
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
      puts "[OEAlignPCA] nelder-mead best=α#{(fine_al/deg2rad).round(3)}° β#{(fine_be/deg2rad).round(3)}° γ#{(fine_ga/deg2rad).round(3)}° vol=#{fine_vol.round(4)}"

      current_vol = bb_vol_3d(pts, 1,0,0, 0,1,0, 0,0,1)
      if fine_vol >= current_vol * 0.99
        puts "[OEAlignPCA] already optimal (improvement < 1%)"
        return
      end

      al = fine_al; be = fine_be; ga = fine_ga
      ca = Math.cos(al); sa = Math.sin(al)
      cb = Math.cos(be); sb = Math.sin(be)
      cg = Math.cos(ga); sg = Math.sin(ga)

      # Best rotation in definition space (column-major for SketchUp)
      r_best = Geom::Transformation.new([
        ca*cb*cg - sa*sg,   sa*cb*cg + ca*sg,  -sb*cg,  0,
        -ca*cb*sg - sa*cg,  -sa*cb*sg + ca*cg,  sb*sg,  0,
        ca*sb,               sa*sb,              cb,     0,
        0, 0, 0, 1
      ])
      r_best_inv = r_best.inverse

      instance.definition.entities.transform_entities(r_best, instance.definition.entities.to_a)
      instance.definition.instances.each do |inst|
        before = inst.transformation.origin
        inst.transformation = inst.transformation * r_best_inv
        after  = inst.transformation.origin
        puts "[OEAlignPCA]   origin: #{before.to_a.map{|v|v.round(3)}} → #{after.to_a.map{|v|v.round(3)}}"
      end
      permute_axes_by_extent(instance)
      t1 = instance.transformation
      det1 = t1.xaxis.dot(t1.yaxis.cross(t1.zaxis)) >= 0 ? "RH" : "LH"
      puts "[OEAlignPCA] done handedness=#{det1}"
    end

    # Tool class that runs align_x_to_dominant_edge then align_to_min_bb in one
    # operation. Recurrent: stays active for repeated clicks.
    class OEAlignOptimalTool

      BB_EDGES = [[0,1],[0,2],[1,3],[2,3],[4,5],[4,6],[5,7],[6,7],[0,4],[1,5],[2,6],[3,7]].freeze

      def initialize(instances)
        @model     = Sketchup.active_model
        @instances = instances
        @hovered   = nil
      end

      def activate
        update_vcb
        UI.start_timer(0, false) { apply(@instances) unless @instances.empty? }
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

      def onMouseMove(_flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        entity = ph.best_picked
        candidate = (entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)) ? entity : nil
        if candidate != @hovered
          @hovered = candidate
          view.invalidate
        end
      end

      def draw(view)
        return unless @hovered&.valid?
        t = @hovered.transformation
        def_bb = @hovered.definition.bounds
        corners = 8.times.map { |i| t * def_bb.corner(i) }
        eye = view.camera.eye
        view.line_width = 2
        view.drawing_color = Sketchup::Color.new(255, 165, 0)
        BB_EDGES.each do |a, b|
          pa = corners[a].offset((eye - corners[a]).normalize, 0.1)
          pb = corners[b].offset((eye - corners[b]).normalize, 0.1)
          view.draw(GL_LINES, [pa, pb])
        end
      end

      def getExtents
        bb = Geom::BoundingBox.new
        if @hovered&.valid?
          t = @hovered.transformation
          8.times { |i| bb.add(t * @hovered.definition.bounds.corner(i)) }
        end
        bb
      end

      def enableVCB?
        true
      end

      def onLButtonDown(_flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        entity = ph.best_picked
        return unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
        @model.selection.clear
        @model.selection.add(entity)
        apply([entity])
      end

      def onKeyDown(key, _repeat, _flags, _view)
        @model.select_tool(nil) if key == 27 # Escape
      end

      private

      def apply(instances)
        return if instances.empty?
        @model.start_operation("Orienter Express: Optimal Axis Alignment", true)
        instances.each do |inst|
          next unless inst.valid?
          OrienterExpress.send(:align_x_to_dominant_edge, inst)
          OrienterExpress.send(:align_to_min_bb, inst)
        end
        @model.commit_operation
        @model.active_view.invalidate
      end

      def update_vcb
        Sketchup.set_status_text(Lang.commands.oealignoptimal.vcb_hint.to_s, 0)
      end
    end

    def self.oealignoptimal
      model   = Sketchup.active_model
      targets = instances(model.selection)
      model.select_tool(OEAlignOptimalTool.new(targets))
    end

    private_class_method :collect_vertices
    private_class_method :convex_hull_3d
    private_class_method :bb_vol_3d
    private_class_method :planar_normal
    private_class_method :permute_axes_by_extent
    private_class_method :align_to_min_bb
    private_class_method :bake_scale
    private_class_method :align_x_to_dominant_edge
    private_class_method :orient_ground
    private_class_method :orient_to_flow
    private_class_method :face_centroid
    private_class_method :resolved_insertion_point
    private_class_method :move_insertion_to
    private_class_method :vertex_flow_direction
    private_class_method :all_vertex_flow_directions

  end # module OrienterExpress
end # module ASM_Extensions
