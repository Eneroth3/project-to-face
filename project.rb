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

    # Flatten new instances to face's plane.
    flatten_tr = transform_transformation(
      Geom::Transformation.scaling(ORIGIN, 1, 1, 0),
      Geom::Transformation.new(face.vertices.first.position, face.normal)
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

    # Tag group
    # Crop
  end

  # "transform" the base transformation by a modifier transformation.
  def self.transform_transformation(base, modifier)
    modifier*base*modifier.inverse
  end

  # TODO: Extract
  def self.instance?(entity)
    [Sketchup::Group, Sketchup::ComponentInstance].include?(entity.class)
  end
end