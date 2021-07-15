require_relative "project"

class ProjectTool
  def activate
    @hovered_face_path = nil
    @source_instances = Sketchup.active_model.selection.select { |e| instance?(e) }

    update_status_text
  end

  def onCancel(reason, view)
    reset
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
    elsif @hovered_face_path
      click_face
    end
    update_status_text
  end

  def click_instance
    model = Sketchup.active_model
    @source_instances = model.selection.select { |e| instance?(e) }
  end

  def click_face
    Project.project(@source_instances, @hovered_face_path)
    reset
  end

  def resume(view)
    update_status_text
  end

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
