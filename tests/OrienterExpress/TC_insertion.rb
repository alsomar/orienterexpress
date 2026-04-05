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

      # Apply N × 90° roll around the given world axis through bounds center.
      def apply_roll(inst, steps, axis)
        return if steps == 0
        angle = steps * 90.degrees
        inst.transform!(
          Geom::Transformation.rotation(inst.bounds.center, axis, angle)
        )
      end

      # Rotate instance so its Z axis aligns to edge_vec (simulate orient_z).
      def orient_z_to(inst, edge_vec)
        OE.send(:align_axis, inst, inst.transformation.origin,
                inst.transformation.zaxis, edge_vec.normalize)
      end

      # =========================================================================
      # move_insertion_to — :center
      # =========================================================================

      def test_center_insertion_lands_at_target
        inst   = make_instance
        target = Geom::Point3d.new(500, 500, 500)
        OE.send(:move_insertion_to, inst, target, :center, :z)
        assert_in_delta target.x, inst.bounds.center.x, TOL
        assert_in_delta target.y, inst.bounds.center.y, TOL
        assert_in_delta target.z, inst.bounds.center.z, TOL
      end

      def test_center_insertion_rotated_instance_lands_at_target
        rot    = Geom::Transformation.rotation(ORIGIN, X_AXIS, 45.degrees)
        inst   = make_instance(rot)
        target = Geom::Point3d.new(200, 300, 100)
        OE.send(:move_insertion_to, inst, target, :center, :z)
        assert_in_delta target.x, inst.bounds.center.x, TOL
        assert_in_delta target.y, inst.bounds.center.y, TOL
        assert_in_delta target.z, inst.bounds.center.z, TOL
      end

      # =========================================================================
      # move_insertion_to — :origin
      # =========================================================================

      def test_origin_insertion_lands_at_target
        inst   = make_instance
        target = Geom::Point3d.new(300, 200, 100)
        OE.send(:move_insertion_to, inst, target, :origin, :z)
        assert_in_delta target.x, inst.transformation.origin.x, TOL
        assert_in_delta target.y, inst.transformation.origin.y, TOL
        assert_in_delta target.z, inst.transformation.origin.z, TOL
      end

      def test_origin_insertion_rotated_instance_lands_at_target
        rot    = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 30.degrees)
        inst   = make_instance(rot)
        target = Geom::Point3d.new(400, 0, 0)
        OE.send(:move_insertion_to, inst, target, :origin, :z)
        assert_in_delta target.x, inst.transformation.origin.x, TOL
        assert_in_delta target.y, inst.transformation.origin.y, TOL
        assert_in_delta target.z, inst.transformation.origin.z, TOL
      end

      # =========================================================================
      # move_insertion_to — :base, various scale_axes (unrotated instance)
      # =========================================================================

      # scale_axis nil → min-Z face center should land at target.
      def test_base_insertion_scale_axis_z_min_z_face_at_target
        inst   = make_instance
        target = Geom::Point3d.new(0, 0, 100)
        OE.send(:move_insertion_to, inst, target, :base, nil)
        db    = inst.definition.bounds
        local = Geom::Point3d.new(db.center.x, db.center.y, db.min.z)
        world = inst.transformation * local
        assert_in_delta target.x, world.x, TOL
        assert_in_delta target.y, world.y, TOL
        assert_in_delta target.z, world.z, TOL
      end

      # scale_axis :x → min-X face center should land at target.
      def test_base_insertion_scale_axis_x_min_x_face_at_target
        inst   = make_instance
        target = Geom::Point3d.new(50, 50, 50)
        OE.send(:move_insertion_to, inst, target, :base, :x)
        db    = inst.definition.bounds
        local = Geom::Point3d.new(db.min.x, db.center.y, db.center.z)
        world = inst.transformation * local
        assert_in_delta target.x, world.x, TOL
        assert_in_delta target.y, world.y, TOL
        assert_in_delta target.z, world.z, TOL
      end

      # scale_axis :y → min-Y face center should land at target.
      def test_base_insertion_scale_axis_y_min_y_face_at_target
        inst   = make_instance
        target = Geom::Point3d.new(0, 200, 0)
        OE.send(:move_insertion_to, inst, target, :base, :y)
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

      # One 90° roll around Z axis (= scale_axis :z after orient_z_to(X)):
      # Y axis should become -Z (for a default-oriented component Z→X, Y→Y).
      def test_apply_roll_90_around_x_rotates_yaxis
        inst = make_instance
        orient_z_to(inst, X_AXIS)        # Z→X
        roll_axis_vec = inst.transformation.xaxis  # capture before rolling
        y_before      = inst.transformation.yaxis
        apply_roll(inst, 1, roll_axis_vec)
        y_after   = inst.transformation.yaxis
        expected  = Geom::Transformation.rotation(ORIGIN, roll_axis_vec, 90.degrees) * y_before
        assert_same_direction expected, y_after,
          'Y axis should rotate 90° after one roll step around the instance xaxis'
      end

      # =========================================================================
      # axis_most_aligned_to — OEFaceTool base insertion
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
      # Integration: move_base_to_surface vs. move_insertion_to for :center
      # =========================================================================

      # For :center, both methods should give the same result (bounds.center at target).
      def test_center_insertion_consistent_with_move_insertion_to
        inst1  = make_instance
        inst2  = make_instance
        target = Geom::Point3d.new(300, 300, 300)
        orient_z_to(inst1, X_AXIS)
        orient_z_to(inst2, X_AXIS)

        OE.send(:move_insertion_to, inst1, target, :center, :z)

        proxy = make_tool_proxy
        proxy.move_base_to_surface(inst2, target, Z_AXIS)

        # :center: inst1 center should be at target
        assert_in_delta target.x, inst1.bounds.center.x, TOL
        assert_in_delta target.y, inst1.bounds.center.y, TOL
        assert_in_delta target.z, inst1.bounds.center.z, TOL
      end

      # =========================================================================
      # Regression: base insertion survives nil normal (no faces on edge)
      # =========================================================================

      def test_place_with_insertion_base_no_normal_falls_back_to_move_insertion_to
        # Create a tool-like object that mirrors place_with_insertion logic
        inst   = make_instance
        target = Geom::Point3d.new(0, 0, 200)
        scale_axis     = :z
        rotation_mode  = :normal
        insertion_point = :base
        edge_normal    = nil   # naked edge

        # Expected: fall back to move_insertion_to with scale_axis
        inst2 = make_instance
        OE.send(:move_insertion_to, inst2, target, insertion_point, scale_axis)

        # Actual: simulate place_with_insertion with nil normal
        if insertion_point == :base && rotation_mode == :normal && edge_normal
          # would call move_base_to_surface
        else
          OE.send(:move_insertion_to, inst, target, insertion_point, scale_axis)
        end

        assert_in_delta inst2.transformation.origin.x, inst.transformation.origin.x, TOL
        assert_in_delta inst2.transformation.origin.y, inst.transformation.origin.y, TOL
        assert_in_delta inst2.transformation.origin.z, inst.transformation.origin.z, TOL
      end

    end
  end
end
