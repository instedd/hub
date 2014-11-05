class EventHandlersController < ApplicationController
  add_breadcrumb 'Tasks', :connectors_path

  expose(:event_handlers) { current_user.event_handlers }
  expose(:event_handler)

  def index
    add_breadcrumb 'New task'
  end

  def new
    add_breadcrumb 'New task'
  end

  def edit
    add_breadcrumb event_handler.name
  end

  def create
    event_handler.update_attributes params.require(:event_handler).permit!
    if event_handler.save
      redirect_to event_handlers_path, notice: "Task #{event_handler.name} successfully created."
    else
      render action: "new"
    end
  end

  def update
    event_handler.update_attributes params.require(:event_handler).permit!
    if event_handler.save
      redirect_to event_handlers_path, notice: "Task #{event_handler.name} successfully updated."
    else
      render action: "edit"
    end
  end

  def destroy
    event_handler.destroy
    redirect_to event_handlers_path, notice: "Task #{event_handler.name} successfully deleted."
  end

end
