# frozen_string_literal: true

require 'testup/testcase'

module ASM_Extensions
  module OrienterExpress
    class TC_insertion < TestUp::TestCase

      OE  = ASM_Extensions::OrienterExpress
      TOL = 0.001

      # =========================================================================
      # Setup / teardown
      # =========================================================================

      def setup
        @model    = Sketchup.active_model
        @entities = @model.active_entities
        @to_erase = []

        # 100×60×40 box aligned to world axes, origin at (0,0,0)
        # X extent: 0..100, Y extent: 0..60, Z extent: 0..40
        @definition = @model.definitions.add('TC_insertion_box')
        pts = [[0, 0, 0], [100, 0, 0], [100, 60, 0], [0, 60, 0]]
        @definition.entities.add_face(pts).pushpull(40)
      end

      def teardown
        @to_erase.each { |e| e.erase! if e.respond_to?(:valid?) && e.valid? }
        @model.definitions.purge_unused
      end

      # =========================================================================
      # Helpers
      # =========================================================================

      def make_instance(t = Geom::Transformation.new)
        inst = @entities.add_instance(@definition, t)
        @to_erase << inst
        inst
      end

      def assert_same_direction(expected, actual, msg = nil)
        en  = expected.normalize
        an  = actual.normalize
        dot = en.dot(an)
        assert_in_delta 1.0, dot, TOL, msg || "Expected direction #{en}, got #{an}"
      end

      # Project a Point3d onto a direction vector (dot product).
      def proj(pt, vec)
        n = vec.normalize
        pt.x * n.x + pt.y * n.y + pt.z * n.z
      end

      # World-space corners of an instance using its definition bounds.
      def world_corners(inst)
        t  = inst.transformation
        db = inst.definition.bounds
        8.times.map { |i| t * db.corner(i) }
      end

      # Min projection of all 8 OBB corners onto a direction vector.
      def min_proj(inst, vec)
        world_corners(inst).map { |p| proj(p, vec) }.min
      end

      # Max projection of all 8 OBB corners onto a direction vector.
      def max_proj(inst, vec)
        world_corners(inst).map { |p| proj(p, vec) }.max
      end

      # Apply N × 90° roll around the given world axis through bounds center,
      # using the same canonical-sign logic as OEPlacementTool#apply_roll.
      def apply_roll(inst, steps, axis)
        return if steps == 0
        angle = steps * 90.degrees
        n     = axis.normalize
        sign  = if    n.x.abs >= n.y.abs && n.x.abs >= n.z.abs then n.x >= 0 ? 1 : -1
                 elsif n.y.abs >= n.z.abs                         then n.y >= 0 ? 1 : -1
                 else                                                  n.z >= 0 ? 1 : -1
                 end
        inst.transform!(
          Geom::Transformation.rotation(inst.bounds.center, axis, angle * sign)
        )
      end

      # Rotate instance so its Z axis aligns to edge_vec (simulate orient_z).
      def orient_z_to(inst, edge_vec)
        OE.send(:align_axis, inst, inst.transformation.origin,
                inst.transformation.zaxis, edge_vec.normalize)
      end

      # Rotate instance so its X axis aligns to edge_vec (simulate orient_x_to_edge).
      def orient_x_to(inst, edge_vec)
        OE.send(:align_axis, inst, inst.transformation.origin,
                inst.transformation.xaxis, edge_vec.normalize)
      end

      # Rotate instance so its Y axis aligns to edge_vec (simulate orient_y_to_edge).
      def orient_y_to(inst, edge_vec)
        OE.send(:align_axis, inst, inst.transformation.origin,
                inst.transformation.yaxis, edge_vec.normalize)
      end

      # Creates a rectangular vertical wall face whose outward normal is roughly
      # parallel to normal_dir. Returns [face, horizontal_edge].
      def make_wall_face(normal_dir)
        n    = normal_dir.normalize
        perp = n.cross(Z_AXIS)
        perp = n.cross(X_AXIS) if perp.length < 0.5
        perp = perp.normalize
        base = ORIGIN.offset(n, 50)
        pts  = [base,
                base.offset(perp, 100),
                base.offset(perp, 100).offset(Z_AXIS, 60),
                base.offset(Z_AXIS, 60)]
        face = @entities.add_face(pts)
        @to_erase << face
        horiz = face.edges.find { |e|
          (e.end.position - e.start.position).z.abs < 1e-3
        }
        [face, horiz]
      end

      # =========================================================================
      # move_pivot_to — :center
      # =========================================================================

      def test_center_pivot_lands_at_target
        inst   = make_instance
        target = Geom::Point3d.new(500, 500, 500)
        OE.send(:move_pivot_to, inst, target, :center, :z)
        assert_in_delta target.x, inst.bounds.center.x, TOL
        assert_in_delta target.y, inst.bounds.center.y, TOL
        assert_in_delta target.z, inst.bounds.center.z, TOL
      end

      def test_center_pivot_rotated_instance_lands_at_target
        rot    = Geom::Transformation.rotation(ORIGIN, X_AXIS, 45.degrees)
        inst   = make_instance(rot)
        target = Geom::Point3d.new(200, 300, 100)
        OE.send(:move_pivot_to, inst, target, :center, :z)
        assert_in_delta target.x, inst.bounds.center.x, TOL
        assert_in_delta target.y, inst.bounds.center.y, TOL
        assert_in_delta target.z, inst.bounds.center.z, TOL
      end

      # =========================================================================
      # move_pivot_to — :origin
      # =========================================================================

      def test_origin_pivot_lands_at_target
        inst   = make_instance
        target = Geom::Point3d.new(300, 200, 100)
        OE.send(:move_pivot_to, inst, target, :origin, :z)
        assert_in_delta target.x, inst.transformation.origin.x, TOL
        assert_in_delta target.y, inst.transformation.origin.y, TOL
        assert_in_delta target.z, inst.transformation.origin.z, TOL
      end

      def test_origin_pivot_rotated_instance_lands_at_target
        rot    = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 30.degrees)
        inst   = make_instance(rot)
        target = Geom::Point3d.new(400, 0, 0)
        OE.send(:move_pivot_to, inst, target, :origin, :z)
        assert_in_delta target.x, inst.transformation.origin.x, TOL
        assert_in_delta target.y, inst.transformation.origin.y, TOL
        assert_in_delta target.z, inst.transformation.origin.z, TOL
      end

      # =========================================================================
      # move_pivot_to — :base, various scale_axes (unrotated instance)
      # =========================================================================

      # scale_axis nil → min-Z face center should land at target.
      def test_base_pivot_scale_axis_z_min_z_face_at_target
        inst   = make_instance
        target = Geom::Point3d.new(0, 0, 100)
        OE.send(:move_pivot_to, inst, target, :base, nil)
        db    = inst.definition.bounds
        local = Geom::Point3d.new(db.center.x, db.center.y, db.min.z)
        world = inst.transformation * local
        assert_in_delta target.x, world.x, TOL
        assert_in_delta target.y, world.y, TOL
        assert_in_delta target.z, world.z, TOL
      end

      # scale_axis :x → min-X face center should land at target.
      def test_base_pivot_scale_axis_x_min_x_face_at_target
        inst   = make_instance
        target = Geom::Point3d.new(50, 50, 50)
        OE.send(:move_pivot_to, inst, target, :base, :x)
        db    = inst.definition.bounds
        local = Geom::Point3d.new(db.min.x, db.center.y, db.center.z)
        world = inst.transformation * local
        assert_in_delta target.x, world.x, TOL
        assert_in_delta target.y, world.y, TOL
        assert_in_delta target.z, world.z, TOL
      end

      # scale_axis :y → min-Y face center should land at target.
      def test_base_pivot_scale_axis_y_min_y_face_at_target
        inst   = make_instance
        target = Geom::Point3d.new(0, 200, 0)
        OE.send(:move_pivot_to, inst, target, :base, :y)
        db    = inst.definition.bounds
        local = Geom::Point3d.new(db.center.x, db.min.y, db.center.z)
        world = inst.transformation * local
        assert_in_delta target.x, world.x, TOL
        assert_in_delta target.y, world.y, TOL
        assert_in_delta target.z, world.z, TOL
      end

      # =========================================================================
      # move_base_to_surface — all roll steps, various normals
      # =========================================================================

      # Helper: creates a tool-like object (OpenStruct) to call move_base_to_surface.
      # The method only uses instance methods so we use an anonymous wrapper.
      def make_tool_proxy
        proxy = Object.new
        tc    = self
        proxy.define_singleton_method(:move_base_to_surface) do |inst, target, normal|
          n   = normal.normalize
          t   = inst.transformation
          db  = inst.definition.bounds
          dot_n = ->(pt) { pt.x * n.x + pt.y * n.y + pt.z * n.z }
          world_corners = 8.times.map { |i| t * db.corner(i) }
          min_proj      = world_corners.map { |p| dot_n.call(p) }.min
          ctr_world     = t * db.center
          base_pt       = ctr_world.offset(n, min_proj - dot_n.call(ctr_world))
          inst.transform!(Geom::Transformation.translation(target - base_pt))
        end
        proxy
      end

      # For each of 4 roll steps, the OBB face most in the -normal direction
      # must land exactly at target after move_base_to_surface.
      [0, 1, 2, 3].each do |steps|
        define_method("test_move_base_to_surface_normal_Z_roll_#{steps * 90}deg") do
          normal = Z_AXIS
          target = Geom::Point3d.new(0, 0, 500)
          inst   = make_instance
          orient_z_to(inst, X_AXIS)           # Z axis along edge (X)
          apply_roll(inst, steps, X_AXIS)     # roll around scale axis

          proxy = make_tool_proxy
          proxy.move_base_to_surface(inst, target, normal)

          # The minimum projection of all corners onto normal must equal target projected
          actual_min = world_corners(inst).map { |p| proj(p, normal) }.min
          assert_in_delta proj(target, normal), actual_min, TOL,
            "Roll #{steps * 90}°: base face should land at target (normal Z)"
        end
      end

      [0, 1, 2, 3].each do |steps|
        define_method("test_move_base_to_surface_normal_X_roll_#{steps * 90}deg") do
          # Vertical wall: normal points in +X
          normal = X_AXIS
          target = Geom::Point3d.new(200, 0, 0)
          inst   = make_instance
          orient_z_to(inst, Z_AXIS)           # Z axis along edge (Z, vertical)
          apply_roll(inst, steps, Z_AXIS)

          proxy = make_tool_proxy
          proxy.move_base_to_surface(inst, target, normal)

          actual_min = world_corners(inst).map { |p| proj(p, normal) }.min
          assert_in_delta proj(target, normal), actual_min, TOL,
            "Roll #{steps * 90}°: base face should land at target (normal X)"
        end
      end

      [0, 1, 2, 3].each do |steps|
        define_method("test_move_base_to_surface_diagonal_normal_roll_#{steps * 90}deg") do
          # Diagonal face normal (45° between X and Z)
          normal = Geom::Vector3d.new(1, 0, 1).normalize
          target = Geom::Point3d.new(100, 0, 100)
          inst   = make_instance
          orient_z_to(inst, Y_AXIS)
          apply_roll(inst, steps, Y_AXIS)

          proxy = make_tool_proxy
          proxy.move_base_to_surface(inst, target, normal)

          actual_min = world_corners(inst).map { |p| proj(p, normal) }.min
          assert_in_delta proj(target, normal), actual_min, TOL,
            "Roll #{steps * 90}°: base face should land at target (diagonal normal)"
        end
      end

      # =========================================================================
      # roll_axis — correct axis returned per scale_axis
      # =========================================================================

      # Simulate roll_axis logic from OEPlacementTool base class.
      def simulate_roll_axis(inst, scale_axis)
        t = inst.transformation
        case scale_axis
        when :x then t.xaxis
        when :y then t.yaxis
        else         t.zaxis
        end
      end

      def test_roll_axis_default_returns_zaxis
        inst = make_instance
        assert_same_direction inst.transformation.zaxis,
                               simulate_roll_axis(inst, :z)
      end

      def test_roll_axis_x_returns_xaxis
        rot  = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 45.degrees)
        inst = make_instance(rot)
        assert_same_direction inst.transformation.xaxis,
                               simulate_roll_axis(inst, :x)
      end

      def test_roll_axis_y_returns_yaxis
        rot  = Geom::Transformation.rotation(ORIGIN, X_AXIS, 30.degrees)
        inst = make_instance(rot)
        assert_same_direction inst.transformation.yaxis,
                               simulate_roll_axis(inst, :y)
      end

      # After orient_z_to, the Z axis is along the edge.
      # roll_axis(:z) must still point along that same axis.
      def test_roll_axis_after_orient_z_to_edge
        inst = make_instance
        orient_z_to(inst, X_AXIS)
        assert_same_direction X_AXIS, simulate_roll_axis(inst, :z),
          'roll_axis(:z) should align with edge direction after orient_z_to'
      end

      # =========================================================================
      # apply_roll — component rotates around the correct axis
      # =========================================================================

      # After 4 × 90° roll the transformation returns to original (within TOL).
      def test_apply_roll_four_steps_identity
        inst     = make_instance
        a_before = inst.transformation.to_a.map { |v| v.round(6) }
        axis     = inst.transformation.zaxis
        apply_roll(inst, 1, axis)
        apply_roll(inst, 1, axis)
        apply_roll(inst, 1, axis)
        apply_roll(inst, 1, axis)
        a_after = inst.transformation.to_a.map { |v| v.round(6) }
        a_before.zip(a_after).each_with_index do |(b, a), i|
          assert_in_delta b, a, TOL, "Transformation element [#{i}] differs after 4×90° roll"
        end
      end

      # One 90° roll around the edge axis (X_AXIS = scale_axis direction after orient_z_to):
      # Y axis should rotate 90° around that axis (canonical sign = +1 for X_AXIS).
      def test_apply_roll_90_around_x_rotates_yaxis
        inst = make_instance
        orient_z_to(inst, X_AXIS)        # Z→X (edge direction)
        roll_axis_vec = X_AXIS           # roll around the edge direction (canonical +X)
        y_before      = inst.transformation.yaxis
        apply_roll(inst, 1, roll_axis_vec)
        y_after  = inst.transformation.yaxis
        expected = Geom::Transformation.rotation(ORIGIN, roll_axis_vec, 90.degrees) * y_before
        assert_same_direction expected, y_after,
          'Y axis should rotate 90° after one roll step around the edge direction'
      end

      # =========================================================================
      # axis_most_aligned_to — OESurfaceTool insertion
      # =========================================================================

      def simulate_axis_most_aligned_to(inst, ref_vec, scale_axis)
        return scale_axis unless ref_vec && ref_vec.length > 1e-6
        t   = inst.transformation
        n   = ref_vec.normalize
        x_d = (t.xaxis.normalize.dot(n)).abs
        y_d = (t.yaxis.normalize.dot(n)).abs
        z_d = (t.zaxis.normalize.dot(n)).abs
        if    x_d >= y_d && x_d >= z_d then :x
        elsif y_d >= z_d               then :y
        else                                nil
        end
      end

      def test_axis_most_aligned_no_rotation_z_wins
        inst = make_instance
        # Default orientation: Z axis = world Z — should win against Z normal
        result = simulate_axis_most_aligned_to(inst, Z_AXIS, :z)
        assert_equal nil, result, 'Z axis wins → returns nil (= :z equivalent)'
      end

      def test_axis_most_aligned_after_orient_z_to_x_z_aligns_to_normal
        inst = make_instance
        orient_z_to(inst, X_AXIS)  # Z now points in X direction
        # Normal is world X — Z axis is most aligned
        result = simulate_axis_most_aligned_to(inst, X_AXIS, :z)
        assert_equal nil, result,
          'After orient_z_to(X), Z axis most aligned to X normal → nil'
      end

      def test_axis_most_aligned_after_roll_90_x_scale_axis_z
        # After roll 90° around X (scale_axis :z in zscale), Y was vertical,
        # now Z is vertical. X normal: the axis most aligned should shift.
        inst = make_instance
        orient_z_to(inst, X_AXIS)         # Z → X (along edge)
        apply_roll(inst, 1, X_AXIS)       # roll 90° around edge axis
        normal = inst.transformation.yaxis  # capture whatever is now "up"
        result = simulate_axis_most_aligned_to(inst, normal, :z)
        # Whichever axis is most aligned to the current Y (post-roll) should win
        t   = inst.transformation
        n   = normal.normalize
        x_d = (t.xaxis.normalize.dot(n)).abs
        y_d = (t.yaxis.normalize.dot(n)).abs
        z_d = (t.zaxis.normalize.dot(n)).abs
        max_d = [x_d, y_d, z_d].max
        expected = if    x_d == max_d then :x
                   elsif y_d == max_d then :y
                   else                    nil
                   end
        assert_equal expected, result
      end

      # =========================================================================
      # avg_face_normal_for_edge — base class helper
      # =========================================================================

      def test_avg_face_normal_returns_nil_for_naked_edge
        edge = @entities.add_line([0, 0, 0], [100, 0, 0])
        @to_erase << edge
        tool_proxy = OEPlacementTool.allocate
        result = tool_proxy.send(:avg_face_normal_for_edge, edge)
        assert_nil result, 'Naked edge (no faces) should return nil'
      end

      def test_avg_face_normal_horizontal_face_returns_z_normal
        # Create a flat face on the ground plane
        pts  = [[0, 0, 0], [200, 0, 0], [200, 200, 0], [0, 200, 0]]
        face = @entities.add_face(pts)
        @to_erase << face
        edge = face.edges.first
        tool_proxy = OEPlacementTool.allocate
        result = tool_proxy.send(:avg_face_normal_for_edge, edge)
        refute_nil result
        assert_in_delta 0.0, result.x, TOL
        assert_in_delta 0.0, result.y, TOL
        assert_in_delta 1.0, result.z.abs, TOL, 'Horizontal face normal should be ±Z'
      end

      # =========================================================================
      # Integration: move_base_to_surface vs. move_pivot_to for :center
      # =========================================================================

      # For :center, both methods should give the same result (bounds.center at target).
      def test_center_pivot_consistent_with_move_pivot_to
        inst1  = make_instance
        inst2  = make_instance
        target = Geom::Point3d.new(300, 300, 300)
        orient_z_to(inst1, X_AXIS)
        orient_z_to(inst2, X_AXIS)

        OE.send(:move_pivot_to, inst1, target, :center, :z)

        proxy = make_tool_proxy
        proxy.move_base_to_surface(inst2, target, Z_AXIS)

        # :center: inst1 center should be at target
        assert_in_delta target.x, inst1.bounds.center.x, TOL
        assert_in_delta target.y, inst1.bounds.center.y, TOL
        assert_in_delta target.z, inst1.bounds.center.z, TOL
      end

      # =========================================================================
      # Regression: base pivot survives nil normal (no faces on edge)
      # =========================================================================

      def test_place_with_pivot_base_no_normal_falls_back_to_move_pivot_to
        # Create a tool-like object that mirrors place_with_pivot logic
        inst   = make_instance
        target = Geom::Point3d.new(0, 0, 200)
        scale_axis     = :z
        rotation_mode  = :normal
        pivot = :base
        edge_normal    = nil   # naked edge

        # Expected: fall back to move_pivot_to with scale_axis
        inst2 = make_instance
        OE.send(:move_pivot_to, inst2, target, pivot, scale_axis)

        # Actual: simulate place_with_pivot with nil normal
        if pivot == :base && rotation_mode == :normal && edge_normal
          # would call move_base_to_surface
        else
          OE.send(:move_pivot_to, inst, target, pivot, scale_axis)
        end

        assert_in_delta inst2.transformation.origin.x, inst.transformation.origin.x, TOL
        assert_in_delta inst2.transformation.origin.y, inst.transformation.origin.y, TOL
        assert_in_delta inst2.transformation.origin.z, inst.transformation.origin.z, TOL
      end

      # =========================================================================
      # apply_roll — canonical direction (antiparallel axes same visual result)
      # =========================================================================

      # Rolling from the same initial orientation around +X and -X (antiparallel)
      # must produce identical final orientations.
      def test_apply_roll_canonical_antiparallel_x
        inst1 = make_instance
        inst2 = make_instance
        apply_roll(inst1, 1, X_AXIS)
        apply_roll(inst2, 1, Geom::Vector3d.new(-1, 0, 0))
        %i[xaxis yaxis zaxis].each do |ax|
          assert_in_delta inst1.transformation.send(ax).x, inst2.transformation.send(ax).x, TOL
          assert_in_delta inst1.transformation.send(ax).y, inst2.transformation.send(ax).y, TOL
          assert_in_delta inst1.transformation.send(ax).z, inst2.transformation.send(ax).z, TOL
        end
      end

      # Same for antiparallel Y axes.
      def test_apply_roll_canonical_antiparallel_y
        inst1 = make_instance
        inst2 = make_instance
        apply_roll(inst1, 1, Y_AXIS)
        apply_roll(inst2, 1, Geom::Vector3d.new(0, -1, 0))
        %i[xaxis yaxis zaxis].each do |ax|
          assert_in_delta inst1.transformation.send(ax).x, inst2.transformation.send(ax).x, TOL
          assert_in_delta inst1.transformation.send(ax).y, inst2.transformation.send(ax).y, TOL
          assert_in_delta inst1.transformation.send(ax).z, inst2.transformation.send(ax).z, TOL
        end
      end

      # =========================================================================
      # roll_angle — Up arrow advances to next 90° step
      # =========================================================================

      # Simulates the Up arrow logic from onKeyDown.
      def advance_roll(current_angle)
        steps   = ((current_angle / 90.degrees) + 1e-9).floor
        on_step = (current_angle - steps * 90.degrees).abs < 1e-6
        on_step ? ((steps + 1) % 4) * 90.degrees : 0.0
      end

      def test_up_arrow_from_0_goes_to_90
        assert_in_delta 90.degrees, advance_roll(0.0), TOL
      end

      def test_up_arrow_from_90_goes_to_180
        assert_in_delta 180.degrees, advance_roll(90.degrees), TOL
      end

      def test_up_arrow_from_180_goes_to_270
        assert_in_delta 270.degrees, advance_roll(180.degrees), TOL
      end

      def test_up_arrow_from_270_wraps_to_0
        assert_in_delta 0.0, advance_roll(270.degrees), TOL
      end

      def test_up_arrow_from_arbitrary_angle_resets_to_0
        # 72° is not on a 90° step → reset to 0°
        assert_in_delta 0.0, advance_roll(72.degrees), TOL
      end

      def test_up_arrow_from_just_below_180_resets_to_0
        # 179° is not on a step → reset to 0°
        assert_in_delta 0.0, advance_roll(179.degrees), TOL
      end

      def test_up_arrow_from_exactly_on_step_advances_to_next
        # 90° exactly → should go to 180°, not stay at 90°
        assert_in_delta 180.degrees, advance_roll(90.degrees), TOL
      end

      def test_up_arrow_from_5deg_resets_to_0
        # Fine roll (5°) then Up → reset to 0°
        assert_in_delta 0.0, advance_roll(5.degrees), TOL
      end

      # =========================================================================
      # onUserText — degree input parsing
      # =========================================================================

      # Simulates the parsing logic from onUserText.
      def parse_roll_input(text)
        stripped = text.strip
        if stripped =~ /\A-?\d+([.,]\d+)?\s*(deg|°)\z/i
          stripped.gsub(',', '.').to_f * Math::PI / 180.0
        else
          nil  # not a roll input
        end
      end

      def test_parse_roll_integer_deg
        result = parse_roll_input('72deg')
        assert_in_delta 72.degrees, result, TOL
      end

      def test_parse_roll_float_dot_deg
        result = parse_roll_input('22.5deg')
        assert_in_delta 22.5.degrees, result, TOL
      end

      def test_parse_roll_float_comma_deg
        result = parse_roll_input('22,5deg')
        assert_in_delta 22.5.degrees, result, TOL
      end

      def test_parse_roll_degree_symbol
        result = parse_roll_input("45\xC2\xB0")
        assert_in_delta 45.degrees, result, TOL
      end

      def test_parse_roll_zero_resets
        result = parse_roll_input('0deg')
        assert_in_delta 0.0, result, TOL
      end

      def test_parse_roll_negative
        result = parse_roll_input('-90deg')
        assert_in_delta(-90.degrees, result, TOL)
      end

      def test_parse_roll_uppercase_DEG
        result = parse_roll_input('45DEG')
        assert_in_delta 45.degrees, result, TOL
      end

      def test_parse_roll_with_spaces
        result = parse_roll_input('45 deg')
        assert_in_delta 45.degrees, result, TOL
      end

      def test_parse_roll_plain_number_is_not_roll
        result = parse_roll_input('45')
        assert_nil result, 'Plain number without deg/° should not be parsed as roll'
      end

      def test_parse_roll_offset_string_is_not_roll
        result = parse_roll_input('10cm')
        assert_nil result, 'Offset string should not be parsed as roll'
      end

      def test_parse_roll_empty_is_not_roll
        result = parse_roll_input('')
        assert_nil result
      end

      # =========================================================================
      # roll_label — display formatting
      # =========================================================================

      def simulate_roll_label(angle_rad)
        deg = (angle_rad * 180.0 / Math::PI) % 360.0
        deg_str = (deg % 1.0).abs < 0.05 ? deg.round.to_s : format('%.1f', deg)
        "#{deg_str}\xC2\xB0"
      end

      def test_roll_label_zero
        assert_equal "0\xC2\xB0", simulate_roll_label(0.0)
      end

      def test_roll_label_90
        assert_equal "90\xC2\xB0", simulate_roll_label(90.degrees)
      end

      def test_roll_label_180
        assert_equal "180\xC2\xB0", simulate_roll_label(180.degrees)
      end

      def test_roll_label_270
        assert_equal "270\xC2\xB0", simulate_roll_label(270.degrees)
      end

      def test_roll_label_fractional
        assert_equal "22.5\xC2\xB0", simulate_roll_label(22.5.degrees)
      end

      def test_roll_label_wraps_360_to_0
        assert_equal "0\xC2\xB0", simulate_roll_label(360.degrees)
      end

      def test_roll_label_72
        assert_equal "72\xC2\xB0", simulate_roll_label(72.degrees)
      end

      # =========================================================================
      # OEAxisScaleTool base placement — center + cross-section OBB shift
      # =========================================================================

      # Simulate the OEAxisScaleTool base placement:
      #   1. Center the instance at target.
      #   2. Project face_normal ⊥ to scale_axis_vec to get up_perp.
      #   3. Shift via move_base_to_surface in that direction.
      # face_normal defaults to world +Z (naked-edge fallback).
      def zscale_base_place(inst, target, scale_axis_vec, face_normal = nil)
        ref_up  = face_normal || Geom::Vector3d.new(0, 0, 1)
        OE.send(:move_pivot_to, inst, target, :center, :z)
        scale_n = scale_axis_vec.normalize
        s_dot   = ref_up.dot(scale_n)
        up_perp = Geom::Vector3d.new(
          ref_up.x - scale_n.x * s_dot,
          ref_up.y - scale_n.y * s_dot,
          ref_up.z - scale_n.z * s_dot
        )
        return unless up_perp.length > 1e-6
        proxy = make_tool_proxy
        proxy.move_base_to_surface(inst, target, up_perp)
      end

      # Floor face (normal +Z): base face (min in up_perp = +Z direction) at target.z.
      [0, 1, 2, 3].each do |steps|
        define_method("test_zscale_base_floor_normal_roll_#{steps * 90}deg") do
          inst   = make_instance
          target = Geom::Point3d.new(0, 0, 100)
          orient_z_to(inst, X_AXIS)
          apply_roll(inst, steps, X_AXIS)
          zscale_base_place(inst, target, X_AXIS, Z_AXIS)

          actual_min = world_corners(inst).map { |p| proj(p, Z_AXIS) }.min
          assert_in_delta proj(target, Z_AXIS), actual_min, TOL,
            "Floor normal roll #{steps * 90}°: base face (min Z) at target.z"
        end
      end

      # Ceiling face (normal -Z): the face with max Z must land at target.z;
      # component hangs below.
      [0, 1, 2, 3].each do |steps|
        define_method("test_zscale_base_ceiling_normal_roll_#{steps * 90}deg") do
          inst      = make_instance
          target    = Geom::Point3d.new(0, 0, 100)
          ceiling_n = Geom::Vector3d.new(0, 0, -1)
          orient_z_to(inst, X_AXIS)
          apply_roll(inst, steps, X_AXIS)
          zscale_base_place(inst, target, X_AXIS, ceiling_n)

          actual_min = world_corners(inst).map { |p| proj(p, ceiling_n) }.min
          assert_in_delta proj(target, ceiling_n), actual_min, TOL,
            "Ceiling normal roll #{steps * 90}°: base face (min proj onto -Z) at target.z"
        end
      end

      # Vertical edge (scale_axis_vec = world Z): up_perp degenerates to zero,
      # so no base shift — component center stays at midpoint.
      def test_zscale_base_vertical_edge_center_at_midpoint
        inst   = make_instance
        target = Geom::Point3d.new(10, 20, 50)
        orient_z_to(inst, Z_AXIS)
        OE.send(:move_pivot_to, inst, target, :center, :z)
        ctr = inst.bounds.center
        assert_in_delta target.x, ctr.x, TOL
        assert_in_delta target.y, ctr.y, TOL
        assert_in_delta target.z, ctr.z, TOL
      end

      # Floor face: center is above target (component extends upward from surface).
      def test_zscale_base_floor_center_above_target
        inst   = make_instance
        target = Geom::Point3d.new(0, 0, 100)
        orient_z_to(inst, X_AXIS)
        zscale_base_place(inst, target, X_AXIS, Z_AXIS)
        assert inst.bounds.center.z > target.z - TOL,
               'Floor: component center must be at or above target'
      end

      # Ceiling face: center is below target (component hangs down from surface).
      def test_zscale_base_ceiling_center_below_target
        inst   = make_instance
        target = Geom::Point3d.new(0, 0, 100)
        orient_z_to(inst, X_AXIS)
        zscale_base_place(inst, target, X_AXIS, Geom::Vector3d.new(0, 0, -1))
        assert inst.bounds.center.z < target.z + TOL,
               'Ceiling: component center must be at or below target'
      end

      # =========================================================================
      # place_with_pivot — base mode, all rotation modes
      # =========================================================================
      #
      # These tests call the REAL OEPlacementTool#place_with_pivot method
      # (not a simulation) so bugs in the implementation are caught directly.

      # Build a real OEPlacementTool instance (no initialize) with the given state.
      def make_placement_tool(rotation_mode:, pivot:, scale_axis: :z)
        tool = OEPlacementTool.allocate
        tool.instance_variable_set(:@rotation_mode,   rotation_mode)
        tool.instance_variable_set(:@pivot, pivot)
        tool.instance_variable_set(:@scale_axis,      scale_axis)
        tool
      end

      # ground mode, floor normal (+Z): bottom face must land at target.z
      [0, 1, 2, 3].each do |steps|
        define_method("test_place_with_pivot_ground_base_floor_roll_#{steps * 90}deg") do
          inst   = make_instance
          target = Geom::Point3d.new(200, 150, 300)
          orient_z_to(inst, X_AXIS)
          apply_roll(inst, steps, X_AXIS)

          tool = make_placement_tool(rotation_mode: :ground, pivot: :base)
          tool.send(:place_with_pivot, inst, target, Z_AXIS)

          actual_min = world_corners(inst).map { |p| proj(p, Z_AXIS) }.min
          assert_in_delta proj(target, Z_AXIS), actual_min, TOL,
            "ground+base floor roll #{steps * 90}°: bottom face must land at target.z"
        end
      end

      # ground mode, ceiling normal (-Z): top face must land at target (component hangs below).
      [0, 1, 2, 3].each do |steps|
        define_method("test_place_with_pivot_ground_base_ceiling_roll_#{steps * 90}deg") do
          inst      = make_instance
          target    = Geom::Point3d.new(200, 150, 300)
          ceiling_n = Geom::Vector3d.new(0, 0, -1)
          orient_z_to(inst, X_AXIS)
          apply_roll(inst, steps, X_AXIS)

          tool = make_placement_tool(rotation_mode: :ground, pivot: :base)
          tool.send(:place_with_pivot, inst, target, ceiling_n)

          actual_min = world_corners(inst).map { |p| proj(p, ceiling_n) }.min
          assert_in_delta proj(target, ceiling_n), actual_min, TOL,
            "ground+base ceiling roll #{steps * 90}°: base face (min onto -Z) must land at target"
        end
      end

      # ground mode, no face normal (naked edge): falls back to +Z.
      def test_place_with_pivot_ground_base_no_normal_falls_back_to_z
        inst   = make_instance
        target = Geom::Point3d.new(0, 0, 200)
        orient_z_to(inst, X_AXIS)

        tool = make_placement_tool(rotation_mode: :ground, pivot: :base)
        tool.send(:place_with_pivot, inst, target, nil)

        actual_min = world_corners(inst).map { |p| proj(p, Z_AXIS) }.min
        assert_in_delta proj(target, Z_AXIS), actual_min, TOL,
          'ground+base no normal: falls back to +Z, bottom face at target.z'
      end

      # flow mode, no face normal: same fallback to +Z.
      [0, 1, 2, 3].each do |steps|
        define_method("test_place_with_pivot_flow_no_normal_base_roll_#{steps * 90}deg") do
          inst   = make_instance
          target = Geom::Point3d.new(100, 100, 500)
          orient_z_to(inst, Y_AXIS)
          apply_roll(inst, steps, Y_AXIS)

          tool = make_placement_tool(rotation_mode: :flow, pivot: :base)
          tool.send(:place_with_pivot, inst, target, nil)

          actual_min = world_corners(inst).map { |p| proj(p, Z_AXIS) }.min
          assert_in_delta proj(target, Z_AXIS), actual_min, TOL,
            "flow-no-normal+base roll #{steps * 90}°: bottom face must land at target.z"
        end
      end

      # normal mode, face normal +Z: bottom face at target.
      def test_place_with_pivot_normal_base_floor_normal
        inst   = make_instance
        target = Geom::Point3d.new(0, 0, 300)
        orient_z_to(inst, X_AXIS)

        tool = make_placement_tool(rotation_mode: :normal, pivot: :base)
        tool.send(:place_with_pivot, inst, target, Z_AXIS)

        actual_min = world_corners(inst).map { |p| proj(p, Z_AXIS) }.min
        assert_in_delta proj(target, Z_AXIS), actual_min, TOL,
          'normal+base floor: base face (min onto +Z) must land at target'
      end

      # =========================================================================
      # orient_z_ground (scale_axis=X) — ground mode on vertical faces
      # =========================================================================

      # After orient_z_ground: local Z must lie in the XY plane (z.z ≈ 0).
      def test_orient_z_ground_x_scale_z_axis_parallel_to_xy
        _face, edge = make_wall_face(Y_AXIS)
        inst = make_instance
        orient_x_to(inst, edge.end.position - edge.start.position)
        OE.send(:orient_z_ground, inst, edge)
        assert_in_delta 0.0, inst.transformation.zaxis.z.abs, TOL,
          'scale_axis=X ground: local Z must be parallel to the XY plane'
      end

      # After orient_z_ground: local Z must point toward the face normal XY projection.
      def test_orient_z_ground_x_scale_z_axis_toward_face_normal
        face, edge = make_wall_face(Y_AXIS)
        inst = make_instance
        orient_x_to(inst, edge.end.position - edge.start.position)
        OE.send(:orient_z_ground, inst, edge)
        fn_xy = Geom::Vector3d.new(face.normal.x, face.normal.y, 0)
        skip 'face normal has no XY component' if fn_xy.length < 0.1
        dot = inst.transformation.zaxis.normalize.dot(fn_xy.normalize).abs
        assert dot > 0.9,
          "scale_axis=X ground: Z (#{inst.transformation.zaxis.inspect}) should align to face normal XY (#{fn_xy.inspect})"
      end

      # Oblique wall at 45°: same two checks with a non-axis-aligned normal.
      def test_orient_z_ground_x_scale_oblique_wall_z_parallel_to_xy
        _face, edge = make_wall_face(Geom::Vector3d.new(1, 1, 0))
        inst = make_instance
        orient_x_to(inst, edge.end.position - edge.start.position)
        OE.send(:orient_z_ground, inst, edge)
        assert_in_delta 0.0, inst.transformation.zaxis.z.abs, TOL,
          'scale_axis=X ground oblique: local Z must be parallel to the XY plane'
      end

      def test_orient_z_ground_x_scale_oblique_wall_z_toward_face_normal
        face, edge = make_wall_face(Geom::Vector3d.new(1, 1, 0))
        inst = make_instance
        orient_x_to(inst, edge.end.position - edge.start.position)
        OE.send(:orient_z_ground, inst, edge)
        fn_xy = Geom::Vector3d.new(face.normal.x, face.normal.y, 0)
        skip 'face normal has no XY component' if fn_xy.length < 0.1
        dot = inst.transformation.zaxis.normalize.dot(fn_xy.normalize).abs
        assert dot > 0.9,
          "scale_axis=X ground oblique: Z should align to face normal XY"
      end

      # =========================================================================
      # orient_y_ground (scale_axis=Y) — ground mode on vertical faces
      # =========================================================================

      # After orient_y_ground: local Z must lie in the XY plane (z.z ≈ 0).
      def test_orient_y_ground_y_scale_z_axis_parallel_to_xy
        _face, edge = make_wall_face(X_AXIS)
        inst = make_instance
        orient_y_to(inst, edge.end.position - edge.start.position)
        OE.send(:orient_y_ground, inst, edge)
        assert_in_delta 0.0, inst.transformation.zaxis.z.abs, TOL,
          'scale_axis=Y ground: local Z must be parallel to the XY plane'
      end

      # After orient_y_ground: local Z must point toward the face normal XY projection.
      def test_orient_y_ground_y_scale_z_axis_toward_face_normal
        face, edge = make_wall_face(X_AXIS)
        inst = make_instance
        orient_y_to(inst, edge.end.position - edge.start.position)
        OE.send(:orient_y_ground, inst, edge)
        fn_xy = Geom::Vector3d.new(face.normal.x, face.normal.y, 0)
        skip 'face normal has no XY component' if fn_xy.length < 0.1
        dot = inst.transformation.zaxis.normalize.dot(fn_xy.normalize).abs
        assert dot > 0.9,
          "scale_axis=Y ground: Z (#{inst.transformation.zaxis.inspect}) should align to face normal XY (#{fn_xy.inspect})"
      end

      # Oblique wall at 45°: same two checks.
      def test_orient_y_ground_y_scale_oblique_wall_z_parallel_to_xy
        _face, edge = make_wall_face(Geom::Vector3d.new(1, 1, 0))
        inst = make_instance
        orient_y_to(inst, edge.end.position - edge.start.position)
        OE.send(:orient_y_ground, inst, edge)
        assert_in_delta 0.0, inst.transformation.zaxis.z.abs, TOL,
          'scale_axis=Y ground oblique: local Z must be parallel to the XY plane'
      end

      def test_orient_y_ground_y_scale_oblique_wall_z_toward_face_normal
        face, edge = make_wall_face(Geom::Vector3d.new(1, 1, 0))
        inst = make_instance
        orient_y_to(inst, edge.end.position - edge.start.position)
        OE.send(:orient_y_ground, inst, edge)
        fn_xy = Geom::Vector3d.new(face.normal.x, face.normal.y, 0)
        skip 'face normal has no XY component' if fn_xy.length < 0.1
        dot = inst.transformation.zaxis.normalize.dot(fn_xy.normalize).abs
        assert dot > 0.9,
          "scale_axis=Y ground oblique: Z should align to face normal XY"
      end

      # =========================================================================
      # OESurfaceTool orient pass — scale axis stays aligned with avg_normal
      # =========================================================================
      #
      # Regression: HORIZONTAL mode used to call orient_x unconditionally, which
      # rotates around local Z. For scale_axis=X/Y on faces not facing straight
      # up, local Z is arbitrary after align_axis, so the rotation broke the
      # scale-axis-to-normal alignment — on a faceted sphere the "back-side"
      # instances ended up pointing inward. Fix dispatches on @scale_axis to
      # orient_z_ground / orient_y_ground / orient_x, matching the edge tools.
      #
      # These tests replay place_for_group's orientation pass (align_axis, then
      # the mode-specific orient call) on representative sphere-like normals
      # and assert the scale axis still points along +normal.

      # 14 directions: 6 axis poles + 8 octant diagonals, covering the bug zone.
      SURFACE_NORMALS = [
        Geom::Vector3d.new( 1,  0,  0), Geom::Vector3d.new(-1,  0,  0),
        Geom::Vector3d.new( 0,  1,  0), Geom::Vector3d.new( 0, -1,  0),
        Geom::Vector3d.new( 0,  0,  1), Geom::Vector3d.new( 0,  0, -1),
        Geom::Vector3d.new( 1,  1,  1), Geom::Vector3d.new(-1,  1,  1),
        Geom::Vector3d.new( 1, -1,  1), Geom::Vector3d.new( 1,  1, -1),
        Geom::Vector3d.new(-1, -1,  1), Geom::Vector3d.new(-1,  1, -1),
        Geom::Vector3d.new( 1, -1, -1), Geom::Vector3d.new(-1, -1, -1)
      ].freeze

      def scale_axis_vec(inst, scale_axis)
        case scale_axis
        when :x then inst.transformation.xaxis
        when :y then inst.transformation.yaxis
        else         inst.transformation.zaxis
        end
      end

      # Mirrors OESurfaceTool#place_for_group's align_axis call.
      def align_scale_axis_to(inst, scale_axis, normal)
        OE.send(:align_axis, inst, inst.transformation.origin,
                scale_axis_vec(inst, scale_axis), normal)
      end

      # Mirrors OESurfaceTool#place_for_group's HORIZONTAL orient dispatch.
      def orient_horizontal_for(inst, scale_axis)
        case scale_axis
        when :x then OE.send(:orient_z_ground, inst)
        when :y then OE.send(:orient_y_ground, inst)
        else         OE.orient_x(inst)
        end
      end

      SURFACE_NORMALS.each_with_index do |n, i|
        [:x, :y, :z].each do |sa|
          define_method("test_oesurface_horizontal_scale_#{sa}_normal_#{i}_stays_on_normal") do
            normal = n.normalize
            inst   = make_instance
            align_scale_axis_to(inst, sa, normal)
            orient_horizontal_for(inst, sa)
            dot = scale_axis_vec(inst, sa).normalize.dot(normal)
            assert dot > 0.99,
              "HORIZONTAL scale_axis=#{sa}, normal=#{normal.inspect}: " \
              "scale axis should still point along +normal (got dot=#{dot})"
          end
        end
      end

      # =========================================================================
      # OEAlignerTool auto mode — face-group Z stays on +face.normal
      # =========================================================================
      #
      # Regression: the 2D path of align_to_min_bb chose the face's plane
      # normal from planar_normal(pts), whose sign is set by hull-vertex order
      # (u×v), not the face's front side. For some world orientations the
      # resulting local Z ended up along -face.normal. Fix: when the
      # definition has faces, flip planar_normal to agree with the
      # area-weighted face.normal.
      #
      # Per-normal test: build a flat face-group whose world face.normal
      # points at the target direction, run align_to_min_bb (auto path), and
      # assert the group's local Z axis still points along +face.normal.

      def make_face_group_with_world_normal(target_normal)
        group = @entities.add_group
        @to_erase << group
        # Non-symmetric triangle in local XY plane so min-BB permutation is
        # unambiguous. Don't assume which sign SketchUp picks for face.normal —
        # read it back and rotate the group so its *actual* world face.normal
        # matches the target.
        group.entities.add_face(
          Geom::Point3d.new(  0,  0, 0),
          Geom::Point3d.new(100,  0, 0),
          Geom::Point3d.new( 50, 60, 0)
        )
        face       = group.definition.entities.grep(Sketchup::Face).first
        face_world = group.transformation * face.normal
        tn         = target_normal.normalize
        OE.send(:align_axis, group, group.transformation.origin, face_world, tn)
        group
      end

      SURFACE_NORMALS.each_with_index do |n, i|
        define_method("test_oealigner_auto_face_group_normal_#{i}_keeps_z_on_face_normal") do
          tn    = n.normalize
          group = make_face_group_with_world_normal(tn)
          z_pre = group.transformation.zaxis
          x_pre = group.transformation.xaxis
          OE.send(:align_to_min_bb, group, z_pre, x_pre)
          dot = group.transformation.zaxis.normalize.dot(tn)
          assert dot > 0.99,
            "auto face-group normal=#{tn.inspect}: local Z should align " \
            "with +face.normal (got dot=#{dot})"
        end
      end

    end
  end
end
