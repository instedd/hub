module Entity
  def kind
    :entity
  end

  def lookup(path)
    return self if path.empty?
    property_name = path.shift
    properties[property_name].lookup(path)
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
        [k, {kind: v.kind, path: v.path}]
      end]
    end
    if a = actions
      reflection[:actions] = a
    end
    if e = events
      reflection[:events] = e
    end
    reflection
  end
end
