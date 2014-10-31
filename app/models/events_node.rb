class EventsNode
  def initialize(parent)
    @parent = parent
  end

  def lookup(path)
    return self if path.empty?

    event_name = path.shift
    @parent.events[event_name]
  end

  def reflect
    Hash[@parent.events.map do |k, v|
        [k, {label: v.label, path: v.path}]
    end]
  end
end
