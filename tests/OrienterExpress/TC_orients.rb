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

      def make_edge_between(pt1, pt2)
        edge = @entities.add_line(pt1, pt2)
        @to_erase << edge
        edge
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
        assert_same_direction Y_AXIS, inst.transformation.zaxis,
          'Z should align with edge direction (Y)'
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

    end
  end
end
