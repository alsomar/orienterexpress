module ASM_Extensions
  module OrienterExpress
    # CONSTANTS
    MSG_INVALID_SEL = 'Orienter Express: Please select at least one edge and a group or component.'
    MSG_INVALID_ENT = 'Orienter Express: Invalid entities detected. Aborting operation.'

    # METHODS
    # Scales the entity along the Z-axis based on the length of each edge
    def self.scale_z(entity, edge)
      scale_factor = edge.length / entity.bounds.depth
      transformation = Geom::Transformation.scaling(entity.definition.bounds.center, 1, 1, scale_factor)
      
      if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        entity.transform!(transformation)
      end
    end
    
    # Applies uniform scaling to match Z-lengh and the edge length
    def self.scale_xyz(entity, edge)
      scale_factor = edge.length / entity.bounds.depth
      transformation = Geom::Transformation.scaling(entity.definition.bounds.center, scale_factor, scale_factor, scale_factor)
      
      if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        entity.transform!(transformation)
      end

    end

    # Checks if the selection contains both edges and entities
    def self.valid_selection?(selection)
      entities = selection.grep(Sketchup::Group) + selection.grep(Sketchup::ComponentInstance)
      edges = selection.grep(Sketchup::Edge)
      !entities.empty? && !edges.empty?
    end

    # Checks if both edges and entities are valid
    def self.valid_entities?(edges, entity)
      !edges.empty? && !entity.nil?
    end

    # Retrieves the selected entity
    def self.get_selected_entity(selection)
      selection.find { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
    end

    # Creates a copy of the entity
    def self.create_entity_copy(entity)
      model = Sketchup.active_model
      model.active_entities.add_instance(entity.definition, entity.transformation)
    end

    # Resets entity rotations to zero
    def self.reset_rotations(entity)
      original_center = entity.bounds.center.clone
    
      transformation = entity.transformation
    
      # Aligns the Z-axis with the global Z-axis
      z_axis = transformation.zaxis
      angle_z = z_axis.angle_between(Z_AXIS)
      return if angle_z.abs < 1e-6
    
      axis_z = z_axis.cross(Z_AXIS)
      rotation_z = Geom::Transformation.rotation(ORIGIN, axis_z, angle_z)
      entity.transform!(rotation_z)
    
      current_center = entity.bounds.center
      translation = original_center - current_center
      entity.transform!(Geom::Transformation.translation(translation))
    
      transformation = entity.transformation
    
      # Aligns the X-axis with the desired direction
      x_axis = transformation.xaxis
      angle_x = x_axis.angle_between(X_AXIS)
      return if angle_x.abs < 1e-6
    
      axis_x = x_axis.cross(X_AXIS)
      rotation_x = Geom::Transformation.rotation(ORIGIN, axis_x, angle_x)
      entity.transform!(rotation_x)
    
      current_center = entity.bounds.center
      translation = original_center - current_center
      entity.transform!(Geom::Transformation.translation(translation))
    end

    # Orients the entity along the edge
    def self.orient_entity(entity, edge)
      entity_origin = entity.transformation.origin
      edge_direction = edge.line[1]

      z_axis = entity.transformation.zaxis
      angle = z_axis.angle_between(edge_direction)

      # If the angle between vectors is zero (or very close to zero),
      # then they are already aligned and no rotation is needed.
      return if angle.abs < 1e-6

      axis = z_axis.cross(edge_direction)

      unless axis.length.zero?
        rotation = Geom::Transformation.rotation(entity_origin, axis, angle)
        entity.transform!(rotation)
      end
    end

    # Moves the entity to the edge start
    def self.move_to_edge_start(entity, edge)
      entity_origin = entity.transformation.origin
      edge_start = edge.start.position

      translation = Geom::Transformation.translation(edge_start - entity_origin)
      entity.transform!(translation)
    end

    # Moves the entity to the edge center
    def self.move_center2center(entity, edge)
      gc_center_box = entity.bounds.center
      edg_center = Geom::Point3d.linear_combination(0.5, edge.start.position, 0.5, edge.end.position)

      vector_to_edge = edg_center - gc_center_box

      translation = Geom::Transformation.translation(vector_to_edge)
      entity.transform!(translation)
    end

    # Orients the entity to a specific point
    def self.move_to_vertex(entity, point)
      entity_center = entity.bounds.center

      translation = Geom::Transformation.translation(point - entity_center)
      entity.transform!(translation)
    end

    # MAIN TOOLS
    # Apply orientation and align entities with edge axis
    def self.orienterexpress_axis
      model = Sketchup.active_model
      selection = model.selection

      unless valid_selection?(selection)
        UI.messagebox(MSG_INVALID_SEL)
        return
      end

      model.start_operation('Orienter Express: Local Origin', true)

      entity = get_selected_entity(selection)
      edges = selection.grep(Sketchup::Edge)

      unless valid_entities?(edges, entity)
        UI.messagebox(MSG_INVALID_ENT)
        model.abort_operation
        return
      end

      edges.each do |edge|
        next if edge.length.zero?

        entity_copy = create_entity_copy(entity)
        reset_rotations(entity_copy)
        orient_entity(entity_copy, edge)
        move_to_edge_start(entity_copy, edge)
      end

      model.commit_operation

      Sketchup.active_model.selection.clear
    end

    # Apply orientation and align entities with edge center
    def self.orienterexpress_center
      model = Sketchup.active_model
      selection = model.selection

      unless valid_selection?(selection)
        UI.messagebox(MSG_INVALID_SEL)
        return
      end

      model.start_operation('Orienter Express: Edges Center', true)

      entity = get_selected_entity(selection)
      edges = selection.grep(Sketchup::Edge)

      unless valid_entities?(edges, entity)
        UI.messagebox(MSG_INVALID_ENT)
        model.abort_operation
        return
      end

      edges.each do |edge|
        next if edge.length.zero?
      
        entity_copy = create_entity_copy(entity)
        reset_rotations(entity_copy)
        orient_entity(entity_copy, edge)
        move_center2center(entity_copy, edge)
      end     

      model.commit_operation

      Sketchup.active_model.selection.clear
    end

    # Apply orientation, align entities with edge center, and scale entities along the Z-axis
    def self.orienterexpress_scale_z
      model = Sketchup.active_model
      selection = model.selection
    
      unless valid_selection?(selection)
        UI.messagebox(MSG_INVALID_SEL)
        return
      end
    
      model.start_operation('Orienter Express: Edges Center', true)
    
      entity = get_selected_entity(selection)
      edges = selection.grep(Sketchup::Edge)
    
      unless valid_entities?(edges, entity)
        UI.messagebox(MSG_INVALID_ENT)
        model.abort_operation
        return
      end
    
      edges.each do |edge|
        next if edge.length.zero?
      
        entity_copy = create_entity_copy(entity)
        reset_rotations(entity_copy)
        scale_z(entity_copy, edge)
        orient_entity(entity_copy, edge)
        move_center2center(entity_copy, edge)
      end     
    
      model.commit_operation
    
      Sketchup.active_model.selection.clear
    end

    # Apply orientation, align entities with edge center, and scale uniformly entities
    def self.orienterexpress_scale_xyz
      model = Sketchup.active_model
      selection = model.selection

      unless valid_selection?(selection)
        UI.messagebox(MSG_INVALID_SEL)
        return
      end

      model.start_operation('Orienter Express: Edges Center', true)

      entity = get_selected_entity(selection)
      edges = selection.grep(Sketchup::Edge)

      unless valid_entities?(edges, entity)
        UI.messagebox(MSG_INVALID_ENT)
        model.abort_operation
        return
      end

      edges.each do |edge|
        next if edge.length.zero?
      
        entity_copy = create_entity_copy(entity)
        reset_rotations(entity_copy)
        scale_xyz(entity_copy, edge)
        orient_entity(entity_copy, edge)
        move_center2center(entity_copy, edge)
      end     

      model.commit_operation

      Sketchup.active_model.selection.clear
    end

    # Apply orientation and align entities with vertices
    def self.orienterexpress_vertex
      model = Sketchup.active_model
      selection = model.selection

      unless valid_selection?(selection)
        UI.messagebox(MSG_INVALID_SEL)
        return
      end

      model.start_operation('Orienter Express: Vertices', true)

      entity = get_selected_entity(selection)
      edges = selection.grep(Sketchup::Edge)

      unless valid_entities?(edges, entity)
        UI.messagebox(MSG_INVALID_ENT)
        model.abort_operation
        return
      end

      # Collect all unique vertices from the selected edges
      vertices = edges.flat_map { |edge| [edge.start.position, edge.end.position] }.uniq { |vertex| vertex.to_a }

      vertices.each do |vertex|
        entity_copy = create_entity_copy(entity)
        move_to_vertex(entity_copy, vertex)
      end

      model.commit_operation

      Sketchup.active_model.selection.clear
    end

    # EXTRA TOOLS
    # Resets the rotation of the selected group or component
    def self.orienterexpress_reset_rotations
      model = Sketchup.active_model
      selection = model.selection

      entities = selection.grep(Sketchup::Group) + selection.grep(Sketchup::ComponentInstance)
      
      unless entities.empty?
        model.start_operation('Orienter Express: Reset Rotations', true)
      
        entities.each do |entity|
          reset_rotations(entity)
        end     
      
        model.commit_operation
      
        Sketchup.active_model.selection.clear
      else
        UI.messagebox(MSG_INVALID_SEL)
      end
    end
    
  end # Module OrienterExpress
end # Module ASM_Extensions