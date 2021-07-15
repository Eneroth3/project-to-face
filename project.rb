module Project
  def self.project(source_instances, face_path)
    face_parent = face_path.to_a[-2].definition
    projection_group = face_parent.entities.add_group # has identity transformation.

    # Copy instances to corresponding place inside face's container.
    new_instances = source_instances.map do |source_instance|
      projection_group.entities.add_instance(
        source_instance.definition,
        face_path.transformation.inverse * source_instance.transformation # REVIEW: Check order.
      )
    end

 
    # Tag group
    # Calculate flat transformations on face's plane
    # Explode
    # Reset tags?
    # Crop
  end

  # "transform" the base transformation by a modifier transformation.
  def self.transform_transformation(base, modifier)

  end
end