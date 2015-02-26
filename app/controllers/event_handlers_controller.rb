class EventHandlersController < ApplicationController
  add_breadcrumb 'Tasks', :event_handlers_path

  expose(:event_handlers) { current_user.event_handlers.order(:id) }
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
    load_view_models_params
    event_handler = @param_event.subscribe(@param_action, @param_binding, request_context)
    event_handler.name = params[:event_handler][:name]
    if event_handler.save
      redirect_to event_handlers_path, notice: "Task #{event_handler.name} successfully created."
    else
      render action: "new"
    end
  end

  def update
    event_handler.update_attributes params.require(:event_handler).permit!
    update_from_view_models_params
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

  protected

  def load_view_models_params
    @param_event = resolve_reference(JSON.parse(params[:task][:event]))
    @param_action = resolve_reference(JSON.parse(params[:task][:action]))
    @param_binding = JSON.parse(params[:task][:binding])
  end

  def update_from_view_models_params
    load_view_models_params

    if @param_event
      event_handler.connector = @param_event.connector
      event_handler.event = @param_event.path
    end

    if @param_action
      event_handler.target_connector = @param_action.connector
      event_handler.action = @param_action.path
    end

    event_handler.binding = @param_binding
  end

  def resolve_reference(event_or_action)
    if event_or_action["connector"].present? && event_or_action["path"].present?
      Connector.with_optional_user(current_user).find_by_guid(event_or_action["connector"]).lookup_path(event_or_action["path"], request_context)
    else
      nil
    end
  end
end
