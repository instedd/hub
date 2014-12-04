class EventsNode
  def initialize(parent)
    @parent = parent
  end

  def lookup(path, context)
    return self if path.empty?

    event_name = path.shift
    @parent.events[event_name]
  end

  def reflect(proc, context)
    SimpleProperty.reflect context, @parent.events
  end
end
