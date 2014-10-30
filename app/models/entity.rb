module Entity
  def kind
    :entity
  end

  def lookup(path)
    return self if path.empty?
    property_name = path.shift

    case property_name
    when "$events"
      EventsNode.new(self).lookup(path)
    else
      properties[property_name].lookup(path)
    end
  end

  def properties
  end

  def actions
  end

  def events
  end

  def reflect
    reflection = {}
    if p = properties
      reflection[:properties] = Hash[p.map do |k, v|
        [k, {name: v.name, kind: v.kind, path: v.path}]
      end]
    end
    if a = actions
      reflection[:actions] = a
    end
    if e = events
      reflection[:events] = Hash[e.map do |k, v|
        [k, {name: v.name, path: v.path}]
      end]
    end
    reflection
  end
end
