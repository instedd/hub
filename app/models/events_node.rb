class EventsNode
  def initialize(parent)
    @parent = parent
  end

  def lookup(path, user)
    return self if path.empty?

    event_name = path.shift
    @parent.events[event_name]
  end

  def reflect(proc, user)
    SimpleProperty.reflect proc, @parent.events, user
  end
end
