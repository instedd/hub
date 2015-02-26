module Event
  abstract :sub_path, :label

  attr_reader :parent
  delegate :connector, to: :parent

  def initialize(parent)
    @parent = parent
  end

  def args(context)
    {}
  end

  def reflect_property(context)
    {
      label: label,
      path: path,
      reflect_url: context.reflect_url(path)
    }
  end

  def reflect(context)
    {
      label: label,
      args: args(context),
    }
  end

  def subscribe(action, binding, context)
    EventHandler.create(
      connector: connector,
      event: path,
      action: action.path,
      target_connector: action.connector,
      user: context.user,
      binding: binding,
      poll: respond_to?(:poll)
    )
  end

  def unsubscribe(context)
  end

  def path
    if parent.path.present?
      "#{parent.path}/$events/#{sub_path}"
    else
      "$events/#{sub_path}"
    end
  end

  def load_state
    connector.state && connector.state[path]
  end

  def save_state(value)
    connector.state ||= {}
    connector.state[path] = value
    connector.state_will_change!
    connector.save!
  end
end
