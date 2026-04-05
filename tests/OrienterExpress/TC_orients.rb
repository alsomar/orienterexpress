# frozen_string_literal: true

require 'testup/testcase'

module ASM_Extensions
  module OrienterExpress
    class TC_orients < TestUp::TestCase

      OE  = ASM_Extensions::OrienterExpress
      TOL = 0.001

      # =========================================================================
      # Setup / teardown
      # =========================================================================

      def setup
        @model    = Sketchup.active_model
        @entities = @model.active_entities
        @to_erase = []

        @definition = @model.definitions.add('TC_orients_box')
        pts = [[0, 0, 0], [100, 0, 0], [100, 100, 0], [0, 100, 0]]
        @definition.entities.add_face(pts).pushpull(200)
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

      def make_edge(length)
        edge = @entities.add_line([0, 0, 0], [0, 0, length])
        @to_erase << edge
        edge
      end

      # Returns +1 (RH) or -1 (LH) for the rotational part of a transformation.
      def det_sign(t)
        t.xaxis.dot(t.yaxis.cross(t.zaxis)) >= 0 ? 1 : -1
      end

      # Creates a left-handed instance: X axis flipped → det = -1.
      def make_lh_instance(offset = ORIGIN)
        t = Geom::Transformation.new([-1,0,0,0, 0,1,0,0, 0,0,1,0,
                                      offset.x, offset.y, offset.z, 1])
        make_instance(t)
      end

      def make_edge_between(pt1, pt2)
        edge = @entities.add_line(pt1, pt2)
        @to_erase << edge
        edge
      end

      # Asserts that two values differ by more than delta.
      def refute_in_delta(expected, actual, delta, msg = nil)
        diff = (expected - actual).abs
        refute diff <= delta,
          msg || "Expected |#{expected} - #{actual}| > #{delta}, but difference was #{diff}"
      end

      # Asserts that two vectors point in the same direction (within TOL on dot product).
      def assert_same_direction(expected, actual, msg = nil)
        en  = expected.normalize
        an  = actual.normalize
        dot = en.dot(an)
        assert_in_delta 1.0, dot, TOL, msg || "Expected direction #{en}, got #{an}"
      end

      # Extracts the scale of each axis column from a raw transformation array.
      def axis_scales(a)
        {
          x: Math.sqrt(a[0]**2 + a[1]**2 + a[2]**2),
          y: Math.sqrt(a[4]**2 + a[5]**2 + a[6]**2),
          z: Math.sqrt(a[8]**2 + a[9]**2 + a[10]**2)
        }
      end

      # =========================================================================
      # orient_z — public method
      # =========================================================================

      def test_orient_z_edge_along_x
        inst = make_instance
        edge = make_edge_between([0, 0, 0], [100, 0, 0])
        OE.orient_z(inst, edge)
        assert_same_direction X_AXIS, inst.transformation.zaxis,
          'Z should align with edge direction (X)'
      end

      def test_orient_z_edge_along_y
        inst = make_instance
        edge = make_edge_between([0, 0, 0], [0, 100, 0])
        OE.orient_z(inst, edge)
        # SketchUp may reverse start/end of a new edge, so accept ±Y
        dot = inst.transformation.zaxis.normalize.dot(Y_AXIS)
        assert_in_delta 1.0, dot.abs, TOL, 'Z should align with edge direction (±Y)'
      end

      def test_orient_z_already_along_z_is_noop
        inst     = make_instance
        a_before = inst.transformation.to_a.dup
        edge     = make_edge_between([0, 0, 0], [0, 0, 100])
        OE.orient_z(inst, edge)
        assert_equal a_before, inst.transformation.to_a,
          'No rotation when edge already aligns with component Z'
      end

      # Regression: edge in -Z direction used to silently fail because the
      # cross product residual of two antiparallel unit vectors fell between
      # the 1e-6 and 1e-3 guards, suppressing the rotation entirely.
      def test_orient_z_antiparallel_edge_flips_z
        inst = make_instance                                  # Z = (0,0,1)
        edge = make_edge_between([0, 0, 100], [0, 0, 0])    # direction = (0,0,-1)
        OE.orient_z(inst, edge)
        new_z = inst.transformation.zaxis
        assert_in_delta  0.0, new_z.x, TOL
        assert_in_delta  0.0, new_z.y, TOL
        assert_in_delta(-1.0, new_z.z, TOL, 'Z should flip to -Z for antiparallel edge')
      end

      # =========================================================================
      # align_axis — public method
      # =========================================================================

      def test_align_axis_rotates_z_toward_x
        inst   = make_instance
        center = inst.bounds.center
        OE.align_axis(inst, center, inst.transformation.zaxis, X_AXIS)
        assert_same_direction X_AXIS, inst.transformation.zaxis,
          'Z axis should point along world X after alignment'
      end

      def test_align_axis_rotates_z_toward_y
        inst   = make_instance
        center = inst.bounds.center
        OE.align_axis(inst, center, inst.transformation.zaxis, Y_AXIS)
        assert_same_direction Y_AXIS, inst.transformation.zaxis
      end

      def test_align_axis_already_aligned_leaves_transformation_unchanged
        inst     = make_instance
        a_before = inst.transformation.to_a.dup
        center   = inst.bounds.center
        OE.align_axis(inst, center, Z_AXIS, Z_AXIS)
        assert_equal a_before, inst.transformation.to_a,
          'No rotation should occur when axes are already aligned'
      end

      def test_align_axis_antiparallel_flips_z
        inst   = make_instance
        center = inst.bounds.center
        OE.align_axis(inst, center, Z_AXIS, Z_AXIS.reverse)
        new_z = inst.transformation.zaxis
        assert_in_delta  0.0, new_z.x, TOL
        assert_in_delta  0.0, new_z.y, TOL
        assert_in_delta(-1.0, new_z.z, TOL, 'Z should flip to -Z for antiparallel input')
      end

      def test_align_axis_near_antiparallel_still_rotates
        # Build a target just 0.005 rad past the antiparallel threshold (pi - 0.01)
        tiny   = 0.005
        target = Geom::Vector3d.new(tiny, 0, -Math.sqrt(1 - tiny**2))
        inst   = make_instance
        center = inst.bounds.center
        OE.align_axis(inst, center, Z_AXIS, target)
        assert inst.transformation.zaxis.z < 0,
          'Z should rotate to the negative-Z hemisphere for near-antiparallel input'
      end

      def test_align_axis_zero_length_local_axis_is_noop
        inst     = make_instance
        a_before = inst.transformation.to_a.dup
        center   = inst.bounds.center
        OE.align_axis(inst, center, Geom::Vector3d.new(0, 0, 0), X_AXIS)
        assert_equal a_before, inst.transformation.to_a,
          'Zero-length local axis should be a no-op'
      end

      def test_align_axis_sub_threshold_angle_is_noop
        # 1e-8 rad is well below the 1e-6 guard — no rotation expected
        inst     = make_instance
        a_before = inst.transformation.to_a.dup
        center   = inst.bounds.center
        eps      = 1e-8
        near_z   = Geom::Vector3d.new(eps, 0, Math.sqrt(1 - eps**2))
        OE.align_axis(inst, center, Z_AXIS, near_z)
        assert_equal a_before, inst.transformation.to_a,
          'Angle below 1e-6 rad should not trigger a rotation'
      end

      # =========================================================================
      # orient_ground — private method
      # =========================================================================

      def test_orient_ground_noop_when_local_z_parallel_to_world_z
        # Default instance: local Z = world Z → early return regardless of local_axis
        inst     = make_instance
        a_before = inst.transformation.to_a.dup
        OE.send(:orient_ground, inst, inst.transformation.xaxis)
        assert_equal a_before, inst.transformation.to_a,
          'No rotation when local Z is already parallel to world Z'
      end

      def test_orient_ground_makes_local_x_ground_parallel
        # Tilt 60° around Y: local Z = (sin60, 0, cos60) — not vertical, not horizontal
        rot  = Geom::Transformation.rotation(ORIGIN, Y_AXIS, Math::PI / 3)
        inst = make_instance(rot)
        OE.send(:orient_ground, inst, inst.transformation.xaxis)
        assert_in_delta 0.0, inst.transformation.xaxis.z, TOL,
          'Local X z-component should be 0 (ground-parallel) after orient_ground'
      end

      def test_orient_ground_already_ground_parallel_is_noop
        # 45° around X: local X stays (1,0,0) which is already ground-parallel
        rot      = Geom::Transformation.rotation(ORIGIN, X_AXIS, Math::PI / 4)
        inst     = make_instance(rot)
        x_before = inst.transformation.xaxis
        OE.send(:orient_ground, inst, inst.transformation.xaxis)
        assert_in_delta x_before.x, inst.transformation.xaxis.x, TOL
        assert_in_delta x_before.y, inst.transformation.xaxis.y, TOL
        assert_in_delta x_before.z, inst.transformation.xaxis.z, TOL
      end

      # =========================================================================
      # z_scale — public method
      # =========================================================================

      def test_z_scale_world_z_extent_matches_edge_length
        inst     = make_instance
        edge     = make_edge(300)
        OE.z_scale(inst, edge)
        db       = inst.definition.bounds
        def_z    = (db.max.z - db.min.z).abs
        a        = inst.transformation.to_a
        world_sz = Math.sqrt(a[8]**2 + a[9]**2 + a[10]**2)
        assert_in_delta edge.length, def_z * world_sz, TOL,
          'World Z extent should equal edge length after z_scale'
      end

      def test_z_scale_does_not_change_x_scale
        inst     = make_instance
        edge     = make_edge(300)
        sx_before = axis_scales(inst.transformation.to_a)[:x]
        OE.z_scale(inst, edge)
        sx_after  = axis_scales(inst.transformation.to_a)[:x]
        assert_in_delta sx_before, sx_after, TOL, 'X scale must not change after z_scale'
      end

      def test_z_scale_does_not_change_y_scale
        inst     = make_instance
        edge     = make_edge(300)
        sy_before = axis_scales(inst.transformation.to_a)[:y]
        OE.z_scale(inst, edge)
        sy_after  = axis_scales(inst.transformation.to_a)[:y]
        assert_in_delta sy_before, sy_after, TOL, 'Y scale must not change after z_scale'
      end

      def test_z_scale_pre_scaled_component_preserves_xy
        # Instance with 0.5 pre-scale on X and Y
        pre_scale = Geom::Transformation.scaling(0.5, 0.5, 1.0)
        inst      = make_instance(pre_scale)
        edge      = make_edge(400)
        OE.z_scale(inst, edge)
        scales = axis_scales(inst.transformation.to_a)
        assert_in_delta 0.5, scales[:x], TOL, 'Pre-scaled X (0.5) must be preserved'
        assert_in_delta 0.5, scales[:y], TOL, 'Pre-scaled Y (0.5) must be preserved'
      end

      # =========================================================================
      # uniform_scale — public method
      # =========================================================================

      def test_uniform_scale_world_z_extent_matches_edge_length
        inst     = make_instance
        edge     = make_edge(500)
        OE.uniform_scale(inst, edge)
        db       = inst.definition.bounds
        def_z    = (db.max.z - db.min.z).abs
        a        = inst.transformation.to_a
        world_sz = Math.sqrt(a[8]**2 + a[9]**2 + a[10]**2)
        assert_in_delta edge.length, def_z * world_sz, TOL,
          'World Z extent should equal edge length after uniform_scale'
      end

      def test_uniform_scale_preserves_xz_ratio
        inst = make_instance
        edge = make_edge(500)
        a_before = inst.transformation.to_a
        sx_b     = axis_scales(a_before)[:x]
        sz_b     = axis_scales(a_before)[:z]
        OE.uniform_scale(inst, edge)
        a_after = inst.transformation.to_a
        sx_a    = axis_scales(a_after)[:x]
        sz_a    = axis_scales(a_after)[:z]
        assert_in_delta sx_b / sz_b, sx_a / sz_a, TOL,
          'X/Z scale ratio should be preserved by uniform_scale'
      end

      def test_uniform_scale_preserves_yz_ratio
        inst = make_instance
        edge = make_edge(500)
        a_before = inst.transformation.to_a
        sy_b     = axis_scales(a_before)[:y]
        sz_b     = axis_scales(a_before)[:z]
        OE.uniform_scale(inst, edge)
        a_after = inst.transformation.to_a
        sy_a    = axis_scales(a_after)[:y]
        sz_a    = axis_scales(a_after)[:z]
        assert_in_delta sy_b / sz_b, sy_a / sz_a, TOL,
          'Y/Z scale ratio should be preserved by uniform_scale'
      end

      def test_uniform_scale_pre_scaled_component
        pre_scale = Geom::Transformation.scaling(0.5, 0.5, 1.0)
        inst      = make_instance(pre_scale)
        edge      = make_edge(600)
        a_before  = inst.transformation.to_a
        sx_b = axis_scales(a_before)[:x]
        sz_b = axis_scales(a_before)[:z]
        OE.uniform_scale(inst, edge)
        a_after = inst.transformation.to_a
        sx_a = axis_scales(a_after)[:x]
        sz_a = axis_scales(a_after)[:z]
        assert_in_delta sx_b / sz_b, sx_a / sz_a, TOL,
          'X/Z ratio must be preserved even for pre-scaled components'
      end

      # =========================================================================
      # vertex_flow_direction — private method
      # =========================================================================

      # Single-edge endpoint: direction points away from the only neighbour.
      def test_vfd_single_endpoint_points_outward
        edge   = make_edge_between([0, 0, 0], [100, 0, 0])
        vertex = edge.start   # at (0,0,0)
        dir    = OE.send(:vertex_flow_direction, vertex, [edge])
        # dir = (0,0,0)-(100,0,0) = (-1,0,0)
        assert_same_direction X_AXIS.reverse, dir,
          'Single endpoint should point away from its neighbour'
      end

      # T-junction: two opposing edges cancel, leaving only the stem direction.
      def test_vfd_t_junction_sums_correctly
        e1 = make_edge_between([-100, 0, 0], [0, 0, 0])
        e2 = make_edge_between([100, 0, 0],  [0, 0, 0])
        e3 = make_edge_between([0, 0, 0],    [0, 0, 100])
        vertex = e3.start   # at (0,0,0)
        dir    = OE.send(:vertex_flow_direction, vertex, [e1, e2, e3])
        # dirs: (1,0,0)+(-1,0,0)+(0,0,-1) → sum = (0,0,-1)
        assert_same_direction Z_AXIS.reverse, dir,
          'T-junction should point away from the stem'
      end

      # Symmetric 4-way cross without faces: all vectors cancel, no faces → nil.
      def test_vfd_four_symmetric_edges_no_faces_returns_nil
        e1 = make_edge_between([0, 0, 0], [ 100,    0, 0])
        e2 = make_edge_between([0, 0, 0], [-100,    0, 0])
        e3 = make_edge_between([0, 0, 0], [   0,  100, 0])
        e4 = make_edge_between([0, 0, 0], [   0, -100, 0])
        vertex = e1.start   # at (0,0,0)
        dir    = OE.send(:vertex_flow_direction, vertex, [e1, e2, e3, e4])
        assert_nil dir,
          'Symmetric 4-way cross without faces should return nil'
      end

      # =========================================================================
      # all_vertex_flow_directions — private method
      # =========================================================================

      # Linear A—B—C chain: endpoints get outward directions, interior node
      # has no resolvable direction (antiparallel pair, no cross product).
      def test_avfd_endpoints_of_chain_have_correct_directions
        e_ab = make_edge_between([0, 0, 0],   [100, 0, 0])
        e_bc = make_edge_between([100, 0, 0], [200, 0, 0])

        va = e_ab.start   # (0,0,0)
        vb = e_ab.end     # (100,0,0) — interior
        vc = e_bc.end     # (200,0,0)

        result = OE.send(:all_vertex_flow_directions,
                         va => [e_ab], vb => [e_ab, e_bc], vc => [e_bc])

        assert result.key?(va), 'Endpoint A should have a direction'
        assert result.key?(vc), 'Endpoint C should have a direction'
        assert_same_direction X_AXIS.reverse, result[va],
          'Endpoint A should point away from B (i.e. in -X)'
        assert_same_direction X_AXIS, result[vc],
          'Endpoint C should point away from B (i.e. in +X)'
      end

      # BFS sign correction: a symmetric 4-way cross vertex (candidate ±Z)
      # neighbours a 3D L-corner vertex (reliable dir with Z component).
      # After BFS the cross vertex should end up with the correct Z sign.
      def test_avfd_bfs_propagates_sign_from_reliable_neighbor
        # 4-way cross centred at origin: sum cancels → candidate, cross → ±Z
        e_px = make_edge_between([0, 0, 0], [ 100,   0, 0])
        e_nx = make_edge_between([0, 0, 0], [-100,   0, 0])
        e_py = make_edge_between([0, 0, 0], [   0, 100, 0])
        e_ny = make_edge_between([0, 0, 0], [   0,-100, 0])

        # L-corner at (100,0,0): connects to origin AND upward → reliable (1,0,-1)
        e_bz = make_edge_between([100, 0, 0], [100, 0, 100])

        va = e_px.start   # (0,0,0)   — symmetric candidate
        vb = e_bz.start   # (100,0,0) — reliable 3D corner

        result = OE.send(:all_vertex_flow_directions,
                         va => [e_px, e_nx, e_py, e_ny],
                         vb => [e_px, e_bz])

        dir_a = result[va]
        refute_nil dir_a,
          'Symmetric centre vertex should get a direction via BFS'
        assert dir_a.z < 0,
          "BFS should flip candidate to -Z (corrected by reliable neighbour), got #{dir_a}"
      end

      # =========================================================================
      # align_x_to_dominant_edge — handedness preservation
      # =========================================================================

      def test_align_x_rh_instance_stays_rh
        inst = make_instance
        assert_equal  1, det_sign(inst.transformation)
        OE.send(:align_x_to_dominant_edge, inst)
        assert_equal  1, det_sign(inst.transformation),
          'RH instance must remain RH after align_x_to_dominant_edge'
      end

      def test_align_x_lh_instance_stays_lh
        inst = make_lh_instance
        assert_equal -1, det_sign(inst.transformation)
        OE.send(:align_x_to_dominant_edge, inst)
        assert_equal -1, det_sign(inst.transformation),
          'LH instance must remain LH after align_x_to_dominant_edge'
      end

      def test_align_x_lh_sibling_rh_unaffected
        rh_inst = make_instance
        lh_inst = make_lh_instance(Geom::Point3d.new(500, 0, 0))
        OE.send(:align_x_to_dominant_edge, lh_inst)
        assert_equal  1, det_sign(rh_inst.transformation),
          'RH sibling must remain RH when align_x is applied to the LH instance'
        assert_equal -1, det_sign(lh_inst.transformation)
      end

      def test_align_x_rh_sibling_lh_unaffected
        rh_inst = make_instance
        lh_inst = make_lh_instance(Geom::Point3d.new(500, 0, 0))
        OE.send(:align_x_to_dominant_edge, rh_inst)
        assert_equal  1, det_sign(rh_inst.transformation)
        assert_equal -1, det_sign(lh_inst.transformation),
          'LH sibling must remain LH when align_x is applied to the RH instance'
      end

      # =========================================================================
      # align_to_min_bb — handedness preservation
      # =========================================================================

      def test_align_min_bb_rh_instance_stays_rh
        inst = make_instance
        OE.send(:align_to_min_bb, inst)
        assert_equal  1, det_sign(inst.transformation),
          'RH instance must remain RH after align_to_min_bb'
      end

      def test_align_min_bb_lh_instance_stays_lh
        inst = make_lh_instance
        OE.send(:align_to_min_bb, inst)
        assert_equal -1, det_sign(inst.transformation),
          'LH instance must remain LH after align_to_min_bb'
      end

      def test_align_min_bb_lh_sibling_rh_unaffected
        rh_inst = make_instance
        lh_inst = make_lh_instance(Geom::Point3d.new(500, 0, 0))
        OE.send(:align_to_min_bb, lh_inst)
        assert_equal  1, det_sign(rh_inst.transformation),
          'RH sibling must remain RH when align_to_min_bb is applied to the LH instance'
      end

      def test_align_min_bb_rh_sibling_lh_unaffected
        rh_inst = make_instance
        lh_inst = make_lh_instance(Geom::Point3d.new(500, 0, 0))
        OE.send(:align_to_min_bb, rh_inst)
        assert_equal -1, det_sign(lh_inst.transformation),
          'LH sibling must remain LH when align_to_min_bb is applied to the RH instance'
      end

      # =========================================================================
      # align_x + align_to_min_bb (full OEAlignOptimal) — handedness preservation
      # =========================================================================

      def test_align_optimal_rh_stays_rh
        inst = make_instance
        OE.send(:align_x_to_dominant_edge, inst)
        OE.send(:align_to_min_bb, inst)
        assert_equal  1, det_sign(inst.transformation),
          'RH instance must remain RH after full OEAlignOptimal'
      end

      def test_align_optimal_lh_stays_lh
        inst = make_lh_instance
        OE.send(:align_x_to_dominant_edge, inst)
        OE.send(:align_to_min_bb, inst)
        assert_equal -1, det_sign(inst.transformation),
          'LH instance must remain LH after full OEAlignOptimal'
      end

      def test_align_optimal_mirror_pair_preserve_handedness
        rh_inst = make_instance
        lh_inst = make_lh_instance(Geom::Point3d.new(500, 0, 0))
        # Apply to LH: definition is modified, both instances compensated
        OE.send(:align_x_to_dominant_edge, lh_inst)
        OE.send(:align_to_min_bb, lh_inst)
        assert_equal  1, det_sign(rh_inst.transformation),
          'RH sibling must remain RH after applying OEAlignOptimal to LH of the pair'
        assert_equal -1, det_sign(lh_inst.transformation),
          'LH instance must remain LH after OEAlignOptimal'
      end

      # =========================================================================
      # align_to_min_bb — axis orientation
      # =========================================================================

      # After optimizing a RH instance the three local axes should point into
      # the positive world-axis hemisphere (dot > 0 with their world counterpart).
      def test_align_min_bb_rh_axes_face_positive_world
        inst = make_instance
        OE.send(:align_to_min_bb, inst)
        t = inst.transformation
        assert t.xaxis.x > 0, "Local X (#{t.xaxis}) should point toward +world X"
        assert t.yaxis.y > 0, "Local Y (#{t.yaxis}) should point toward +world Y"
        assert t.zaxis.z > 0, "Local Z (#{t.zaxis}) should point toward +world Z"
      end

      # For a mirror pair, after running OEAlignOptimal on each:
      # · Y and Z axes should be in the same world direction for both instances
      # · X axes should be opposite (the mirror is encoded in det=-1, not in axis flip)
      def test_align_optimal_mirror_pair_axis_consistency
        rh_inst = make_instance
        lh_inst = make_lh_instance(Geom::Point3d.new(500, 0, 0))
        [rh_inst, lh_inst].each do |inst|
          OE.send(:align_x_to_dominant_edge, inst)
          OE.send(:align_to_min_bb, inst)
        end
        rh = rh_inst.transformation
        lh = lh_inst.transformation
        assert_in_delta  rh.yaxis.x, lh.yaxis.x, TOL, 'Y axes should match (x component)'
        assert_in_delta  rh.yaxis.y, lh.yaxis.y, TOL, 'Y axes should match (y component)'
        assert_in_delta  rh.yaxis.z, lh.yaxis.z, TOL, 'Y axes should match (z component)'
        assert_in_delta  rh.zaxis.x, lh.zaxis.x, TOL, 'Z axes should match (x component)'
        assert_in_delta  rh.zaxis.y, lh.zaxis.y, TOL, 'Z axes should match (y component)'
        assert_in_delta  rh.zaxis.z, lh.zaxis.z, TOL, 'Z axes should match (z component)'
        assert_in_delta -rh.xaxis.x, lh.xaxis.x, TOL, 'X axes should be opposite (mirror)'
        assert_in_delta -rh.xaxis.y, lh.xaxis.y, TOL, 'X axes should be opposite (mirror)'
        assert_in_delta -rh.xaxis.z, lh.xaxis.z, TOL, 'X axes should be opposite (mirror)'
      end

      # =========================================================================
      # move_insertion_to — axis-aware base placement
      # Regression: before the fix, scale_axis was ignored and base always used
      # min.z regardless of which axis was active.
      # =========================================================================

      def move_to(inst, point, insertion, axis = nil)
        OE.send(:move_insertion_to, inst, point, insertion, axis)
      end

      def test_move_insertion_center_lands_on_target
        inst   = make_instance
        target = Geom::Point3d.new(500, 500, 500)
        move_to(inst, target, :center)
        assert_in_delta target.x, inst.bounds.center.x, TOL
        assert_in_delta target.y, inst.bounds.center.y, TOL
        assert_in_delta target.z, inst.bounds.center.z, TOL
      end

      def test_move_insertion_origin_lands_on_target
        inst   = make_instance
        target = Geom::Point3d.new(300, 400, 500)
        move_to(inst, target, :origin)
        assert_in_delta target.x, inst.transformation.origin.x, TOL
        assert_in_delta target.y, inst.transformation.origin.y, TOL
        assert_in_delta target.z, inst.transformation.origin.z, TOL
      end

      def test_move_insertion_base_z_uses_min_z
        inst   = make_instance
        target = Geom::Point3d.new(0, 0, 0)
        move_to(inst, target, :base, :z)
        db         = inst.definition.bounds
        world_base = inst.transformation * Geom::Point3d.new(db.center.x, db.center.y, db.min.z)
        assert_in_delta target.x, world_base.x, TOL
        assert_in_delta target.y, world_base.y, TOL
        assert_in_delta target.z, world_base.z, TOL
      end

      def test_move_insertion_base_x_uses_min_x
        inst   = make_instance
        target = Geom::Point3d.new(100, 200, 300)
        move_to(inst, target, :base, :x)
        db         = inst.definition.bounds
        world_base = inst.transformation * Geom::Point3d.new(db.min.x, db.center.y, db.center.z)
        assert_in_delta target.x, world_base.x, TOL, 'base with axis :x should use min.x face'
        assert_in_delta target.y, world_base.y, TOL
        assert_in_delta target.z, world_base.z, TOL
      end

      def test_move_insertion_base_y_uses_min_y
        inst   = make_instance
        target = Geom::Point3d.new(100, 200, 300)
        move_to(inst, target, :base, :y)
        db         = inst.definition.bounds
        world_base = inst.transformation * Geom::Point3d.new(db.center.x, db.min.y, db.center.z)
        assert_in_delta target.x, world_base.x, TOL, 'base with axis :y should use min.y face'
        assert_in_delta target.y, world_base.y, TOL
        assert_in_delta target.z, world_base.z, TOL
      end

      # Regression: axis :x must NOT produce the same result as axis :z when
      # the component is not a cube (different extent in each axis).
      def test_move_insertion_base_x_differs_from_base_z
        # Asymmetric component: 100x100x200 box, so min.x != min.z in world coords
        inst_x = make_instance
        inst_z = make_instance
        target = Geom::Point3d.new(0, 0, 0)
        move_to(inst_x, target, :base, :x)
        move_to(inst_z, target, :base, :z)
        # After placing with :base/:x vs :base/:z the origins must differ
        refute_in_delta inst_x.transformation.origin.x, inst_z.transformation.origin.x, TOL,
          'base :x and base :z should produce different placements for a non-cube component'
      end

      # =========================================================================
      # orient_to_face_edge — axis-aware secondary orientation
      # Regression: hardcoded Z/X axes caused wrong rotation when scale_axis was
      # :x or :y.
      # =========================================================================

      def test_orient_to_face_edge_with_scale_axis_z_aligns_x
        # A flat face in XY plane; axis_idx=0 → align X to dominant edge
        pts  = [[0,0,0],[200,0,0],[200,100,0],[0,100,0]]
        face = @definition.entities.grep(Sketchup::Face).first ||
               @definition.entities.add_face(pts)
        inst = make_instance
        # Rotate so Z points along face normal (world Z) — already default
        OE.send(:orient_to_face_edge, inst, face, 0, :z)
        # X should now be along the dominant (longest) edge direction
        assert_in_delta 0.0, inst.transformation.xaxis.z, TOL,
          'With scale_axis :z, X should be ground-parallel after face edge alignment'
      end

      def test_orient_to_face_edge_with_scale_axis_x_rotates_around_x
        pts  = [[0,0,0],[200,0,0],[200,100,0],[0,100,0]]
        face = @definition.entities.grep(Sketchup::Face).first ||
               @definition.entities.add_face(pts)
        inst = make_instance
        # Align X to face normal first
        t = inst.transformation
        OE.align_axis(inst, t.origin, t.xaxis, face.normal)
        OE.send(:orient_to_face_edge, inst, face, 0, :x)
        # X axis should remain aligned to face normal (rotation was around X)
        assert_same_direction face.normal, inst.transformation.xaxis,
          'With scale_axis :x, X axis should stay aligned to face normal after orient_to_face_edge'
      end

      # =========================================================================
      # orient_ground_around — vertical axis guard
      # Regression: passing a vertical rotation axis caused a divide-by-near-zero.
      # =========================================================================

      def test_orient_ground_around_vertical_axis_is_noop
        inst     = make_instance
        a_before = inst.transformation.to_a.dup
        # Pass world Z as rotation axis — should return early without crash or change
        OE.send(:orient_ground_around, inst, Z_AXIS, X_AXIS)
        assert_equal a_before, inst.transformation.to_a,
          'orient_ground_around should be a no-op when rotation axis is vertical'
      end

      def test_orient_ground_around_makes_target_axis_ground_parallel
        # Tilt 60° around Y so local X is no longer ground-parallel
        rot  = Geom::Transformation.rotation(ORIGIN, Y_AXIS, Math::PI / 3)
        inst = make_instance(rot)
        refute_in_delta 0.0, inst.transformation.xaxis.z, TOL,
          'Precondition: X should not be ground-parallel before orient_ground_around'
        OE.send(:orient_ground_around, inst,
                inst.transformation.zaxis,
                inst.transformation.xaxis)
        assert_in_delta 0.0, inst.transformation.xaxis.z, TOL,
          'X should be ground-parallel after orient_ground_around with rot_axis=Z, target=X'
      end

      # =========================================================================
      # orient_to_face_normal_around — uses explicit rotation axis
      # Regression: calling orient_to_face_normal after orient_x_to_edge would
      # rotate around world Z, undoing the X→edge alignment.
      # =========================================================================

      def test_orient_to_face_normal_around_preserves_rot_axis_direction
        pts  = [[0,0,0],[200,0,0],[200,100,0],[0,100,0]]
        @definition.entities.grep(Sketchup::Face).first ||
          @definition.entities.add_face(pts)
        edge = make_edge_between([0,0,0],[200,0,0])
        inst = make_instance
        # Align X to edge
        OE.orient_x_to_edge(inst, edge)
        x_after_align = inst.transformation.xaxis.clone
        # Apply face-normal rotation around X
        OE.send(:orient_to_face_normal_around, inst, edge,
                inst.transformation.xaxis,
                inst.transformation.zaxis)
        # X axis must remain aligned to edge (rot_axis must not move)
        assert_same_direction x_after_align, inst.transformation.xaxis,
          'Rotation axis (X→edge) must not change after orient_to_face_normal_around'
      end

    end
  end
end
