# frozen_string_literal: true

Sketchup.require "ene_project_to_face/project"
Sketchup.require "ene_project_to_face/generic_tool"

module Eneroth
  module ProjectToFace
    # Tool for selecting what to project against what.
    class ProjectTool < GenericTool
      # @see `GenericTool`
      def self.tool_name
        EXTENSION.name
      end

      # @see `GenericTool`
      def self.tool_description
        EXTENSION.description
      end

      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def activate
        super

        @hovered_face_path = nil
        @source_instances = Sketchup.active_model.selection.select { |e| instance?(e) }

        update_status_text
      end

      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def onCancel(reason, view)
        reset
      end

      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def onMouseMove(flags, x, y, view)
        ph = view.pick_helper(x, y)
        if @source_instances.empty? # TODO: or Ctrl is pressed
          hover_source(ph)
        else
          hover_face(ph)
        end
      end

      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def onLButtonDown(flags, x, y, view)
        if @source_instances.empty? # TODO: or Ctrl is pressed
          click_instance
        elsif @hovered_face_path
          click_face
        end
        update_status_text
      end

      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def resume(view)
        update_status_text
      end

      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def suspend(view)
        view.invalidate
      end

      private

      def reset
        @hovered_face_path = nil
        @source_instances = []
        Sketchup.active_model.selection.clear
        update_status_text
      end

      def update_status_text
        # REVIEW: Extract method to get what stage we are at.
        Sketchup.status_text =
          if @source_instances.empty? # TODO: or Ctrl is pressed
            "Select groups or components to project."
          else
            "Select a face to project to."
          end
      end

      def hover_source(ph)
        model = Sketchup.active_model
        model.selection.clear

        model.selection.add(@source_instances)
        instance = ph.best_picked
        if instance && instance?(instance)
          model.selection.add(instance)
        end
      end

      def hover_face(ph)
        model = Sketchup.active_model
        model.selection.clear
        model.selection.add(@source_instances)

        @hovered_face_path = grep_path(ph, Sketchup::Face)
        return unless @hovered_face_path

        # Prevent picking a face inside of any of the instances we are projecting.
        unless (@hovered_face_path.to_a & @source_instances).empty?
          @hovered_face_path = nil
          return
        end

        model.selection.add(@hovered_face_path.leaf)
      end

      def click_instance
        model = Sketchup.active_model
        @source_instances = model.selection.select { |e| instance?(e) }
      end

      def click_face
        model = Sketchup.active_model
        model.start_operation("Project", true)
        Project.project(@source_instances, @hovered_face_path)
        model.commit_operation
        reset
      end

      def instance?(entity)
        [Sketchup::Group, Sketchup::ComponentInstance].include?(entity.class)
      end

      # Get the pick path that points to an entity of a specific class.
      #
      # @param pick_helper [Sketchup::PickHelper]
      # @param klass [Class]
      #
      # @return [Sketchup::InstancePath, nil]
      def grep_path(pick_helper, klass)
        pick_helper.count.times do |i|
          path = pick_helper.path_at(i)
          next unless path.last.is_a?(klass)

          return Sketchup::InstancePath.new(path)
        end

        nil
      end
    end
  end
end
