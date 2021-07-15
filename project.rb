module Project
  def self.project(source_instances, face_path)
    face = face_path.leaf
    face_parent = face_path.to_a[-2].definition
    projection_group = face_parent.entities.add_group # has identity transformation.

    # Copy instances to corresponding place inside face's container.
    new_instances = source_instances.map do |source_instance|
      projection_group.entities.add_instance(
        source_instance.definition,
        face_path.transformation.inverse * source_instance.transformation # REVIEW: Check order.
      )
    end

    # Transform from face_parent space to a coordinate system where the face
    # is on the X Y plane.
    uv_transformation = Geom::Transformation.new(face.vertices.first.position, face.normal)

    # Flatten new instances to face's plane.
    flatten_tr = transform_transformation(
      Geom::Transformation.scaling(ORIGIN, 1, 1, 0),
      uv_transformation
    )
    new_instances.each { |i| i.transform!(flatten_tr) }

    # Explode
    # TODO: Add user option for this.
    while
      instances = projection_group.entities.select { |e| instance?(e) }
      break if instances.empty?

      instances.each(&:explode)
    end

    # TODO: Add user option
    projection_group.entities.each { |e| e.layer = nil }

    # Crop
    boundary_points = face.vertices.map(&:position)
    # HACK: explode a temp group to merge edges.
    temp_group = projection_group.entities.add_group
    temp_face = temp_group.entities.add_face(boundary_points)
    temp_face.erase!
    temp_group.explode
    projection_group.entities.to_a.each do |edge|
      next unless edge.is_a?(Sketchup::Edge)
      next if on_face?(face, midpoint(edge))

      edge.erase!
    end

    # Purge faces (want a wire frame)
    projection_group.entities.erase_entities(projection_group.entities.grep(Sketchup::Face))
  end

  # "transform" the base transformation by a modifier transformation.
  def self.transform_transformation(base, modifier)
    modifier*base*modifier.inverse
  end

  # TODO: Extract
  def self.instance?(entity)
    [Sketchup::Group, Sketchup::ComponentInstance].include?(entity.class)
  end

  def self.midpoint(edge)
    Geom.linear_combination(0.5, edge.start.position, 0.5, edge.end.position)
  end

  def self.on_face?(face, point)
    face.classify_point(point) == Sketchup::Face::PointInside
  end
end