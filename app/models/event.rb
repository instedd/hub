module Event
  def args
    {}
  end

  def reflect(*)
    {
      label: label,
      args: args,
    }
  end

  def subscribe(action, binding, user)
    EventHandler.create(
      connector: connector,
      event: path,
      action: action.path,
      target_connector: action.connector,
      user: user,
      binding: binding,
      poll: respond_to?(:poll)
    )
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
