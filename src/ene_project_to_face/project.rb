# frozen_string_literal: true

module Eneroth
  module ProjectToFace
    # Low level projection functionality.
    module Project
      # Project groups/components onto a faces nested in a group/component.
      #
      # @param source_instances [Array<Sketchup::group, Sketchup::Component>]
      #   Assumed to be in the active entities.
      def self.project(source_instances, face_path)
        face = face_path.leaf
        projection_group = face.parent.entities.add_group # Has identity transformation.

        source_instances.each do |source_instance|
          traverse_entities(source_instance.definition.entities, source_instance.transformation) do |entity, transformation|
            next unless entity.is_a?(Sketchup::Edge)
            copy_tr = face_path.transformation.inverse * transformation
            points = entity.vertices.map { |v| v.position.transform(copy_tr) }
            points.map! { |pt| pt.project_to_plane(face.plane)}
            projection_group.entities.add_line(points)
          end
        end

        crop(projection_group, face)
      end

      # Walk recursively over entities and sub-entities.
      #
      # @param entities [Sketchup::Entities]
      # @param transform [Geom::Transformation]
      #
      # @yield for each entity and nested entity
      # @yieldparam entity [Sketchup::Drawingelement]
      # @yieldparam transformation [Geom::Transformation]
      def self.traverse_entities(entities, transformation = IDENTITY, &block)
        entities.each do |entity|
          if entity.respond_to?(:definition)
            traverse_entities(
              entity.definition.entities,
              transformation * entity.transformation,
              &block
            )
          end

          yield entity, transformation
        end
      end

      # Erase every edge or part of edge within group that does not lie on face.
      #
      # Assuming group has identity transformation.
      #
      # @param group [Sketchup::Group]
      # @param face[ Sketchup::Face]
      def self.crop(group, face)
        # HACK: explode a temp group to merge edges.
        boundary_points = face.loops[0].vertices.map(&:position)
        temp_group = group.entities.add_group
        temp_face = temp_group.entities.add_face(boundary_points)
        temp_face.erase!
        temp_group.explode
        to_erase = group.entities.select do |edge|
          next unless edge.is_a?(Sketchup::Edge)
          next if edge.deleted?
          next if on_face?(face, midpoint(edge))

          true
        end

        # HACK: Make temp edges from each vertex to prevent collinear edges from
        # merging when connected edges are deleted.
        vertices = to_erase.flat_map(&:vertices).uniq
        temp_edges = vertices.map do |vertex|
          group.entities.add_line(vertex, vertex.position.offset(face.normal))
        end

        group.entities.erase_entities(to_erase)
        group.entities.erase_entities(temp_edges)
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
