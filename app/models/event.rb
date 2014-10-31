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

  def subscribe
    EventSubscription.create(connector: connector, event: path, poll: responds_to?(:poll))
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
