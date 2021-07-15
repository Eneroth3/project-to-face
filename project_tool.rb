reqire_relative "project"

class ProjectTool
  def activate
    @target_face_path = nil
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
    
    face = ph.picked_face
    return unless face
    
    ### transformation = transformation_from_ph(ph, face)
    # TODO: Save path? Or save transformation?
    # hovered_face_path
    
    model.selection.add(face)
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
    puts "Project"
    # take face from selection
    # project stuff to it.
    reset
  end
  
  def reset
    @target_face_path = nil
    @source_instances = []
    Sketchup.active_model.selection.clear
  end
  
  def instance?(entity)
    [Sketchup::Group, Sketchup::ComponentInstance].include?(entity.class)
  end
end

Sketchup.active_model.select_tool(ProjectTool.new)
