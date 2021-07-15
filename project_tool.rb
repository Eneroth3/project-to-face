require_relative "project"

class ProjectTool
  def activate
    @hovered_face_path = nil
    @source_instances = []

    # TODO: If usable_selection?
    @source_instances = Sketchup.active_model.selection.to_a
  end

  def onMouseMove(flags, x, y, view)
    ph = view.pick_helper(x, y)
    if @source_instances.empty? # TODO: or Ctrl is pressed
      hover_source(ph)
    else
      hover_face(ph)
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

    model.selection.add(@hovered_face_path.leaf)
  end

  def onLButtonDown(flags, x, y, view)
    if @source_instances.empty? # TODO: or Ctrl is pressed
      click_instance
    else
      click_face
    end
    # TODO: Update status text. Also on activate.
  end

  def click_instance
    model = Sketchup.active_model
    @source_instances = model.selection.select { |e| instance?(e) }
  end

  def click_face
    Project.project(@source_instances, @hovered_face_path)
    reset
  end

  def reset
    @hovered_face_path = nil
    @source_instances = []
    Sketchup.active_model.selection.clear
  end

  def instance?(entity)
    [Sketchup::Group, Sketchup::ComponentInstance].include?(entity.class)
  end

  # @return [Sketchup::InstancePath, nil]
  def grep_path(ph, klass)
    ph.count.times do |i|
      path = ph.path_at(i)
      next unless path.last.is_a?(klass)

      return Sketchup::InstancePath.new(path)
    end

    nil
  end
end

Sketchup.active_model.select_tool(ProjectTool.new)
