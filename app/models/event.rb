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
end
