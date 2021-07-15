# frozen_string_literal: true

module Eneroth
  module ProjectToFace
    # Low level projection functionality.
    module Project
      # Project groups/components onto a faces nested in a group/component.
      #
      # @param source_instances [Array<Sketchup::group, Sketchup::Component>]
      #   Assumed to be ion the active entities.
      # @param face_path [Sketchup::InstancePath]
      # @param explode [Boolean]
      #   Explode projection to geometry.
      # @param crop [Boolean]
      #   Remove edges outside of face's boundary.
      #   (requires `explode` to be true)
      # @param purge_faces [Boolean]
      #   Remove faces, projects wire frame.
      #   (requires `explode` to be true)
      # @param purge_layers [Boolean]
      #   make projection untagged.
      #   (requires `explode` to be true)
      def self.project(source_instances, face_path, explode = true, crop = true, purge_faces = true,
                       purge_layers = true)
        face = face_path.leaf
        projection_group = face.parent.entities.add_group # Has identity transformation.

        # Copy instances to corresponding place inside face's container.
        new_instances = source_instances.map do |source_instance|
          projection_group.entities.add_instance(
            source_instance.definition,
            face_path.transformation.inverse * source_instance.transformation
          )
        end

        # Transform from face's parent space to a coordinate system where the face
        # is on the X Y plane.
        uv_transformation = Geom::Transformation.new(face.vertices.first.position, face.normal)

        # Flatten new instances to face's plane.
        flatten_tr = transform_transformation(
          Geom::Transformation.scaling(ORIGIN, 1, 1, 0),
          uv_transformation
        )
        new_instances.each { |i| i.transform!(flatten_tr) }

        if explode
          loop do
            instances = projection_group.entities.select { |e| instance?(e) }
            break if instances.empty?

            instances.each(&:explode)
          end

          projection_group.entities.each { |e| e.layer = nil } if purge_layers

          if crop
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
          end

          # Purge faces (want a wire frame)
          if purge_faces
            projection_group.entities.erase_entities(projection_group.entities.grep(Sketchup::Face))
          end
        end
      end

      # "Transform" the base transformation by a modifier transformation.
      #
      # @param base [Geom::Transformation]
      # @param modifier [Geom::Transformation]
      #
      # @return [Geom::Transformation]
      def self.transform_transformation(base, modifier)
        modifier * base * modifier.inverse
      end

      # TODO: Extract
      def self.instance?(entity)
        [Sketchup::Group, Sketchup::ComponentInstance].include?(entity.class)
      end

      # Find midpoint for edge.
      #
      # @param edge [Sketchup::Edge]
      #
      # @return [Geom::Point3d]
      def self.midpoint(edge)
        Geom.linear_combination(0.5, edge.start.position, 0.5, edge.end.position)
      end

      # Test if a point is on a face.
      #
      # @param face [Sketchup::Face]
      # @param point [Geom::Point3d]
      #
      # @return [Boolean]
      def self.on_face?(face, point)
        face.classify_point(point) == Sketchup::Face::PointInside
      end
    end
  end
end
