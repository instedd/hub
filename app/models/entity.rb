module Entity
  attr_reader :parent
  abstract :sub_path

  def node_type
    :entity
  end

  def self.included(mod)
    mod.delegate :connector, to: :parent unless mod.method_defined?(:connector)
  end

  def lookup(path, context)
    return self if path.empty?
    property_name = path.shift

    case property_name
    when "$actions"
      ActionsNode.new(self).lookup(path, context)
    when "$events"
      EventsNode.new(self).lookup(path, context)
    else
      properties(context)[property_name].lookup(path, context)
    end
  end

  def reflect_path
    path
  end

  def path
    if is_a? Connector
      ""
    else
      "#{parent.path}/#{sub_path}"
    end
  end

  def properties(context = nil)
  end

  def actions(context = nil)
  end

  def events
  end

  def raw(context)
    if p = properties(context)
      Hash[p.map do |k, v|
        if v.is_a?(EntitySet)
          [k, context.data_url(v.path)]
        else
          [k, v.value]
        end
      end]
    end
  end

  def reflect_property(context)
    {
      label: label,
      path: path,
      type: node_type,
      reflect_url: context.reflect_url(path)
    }
  end

  def reflect(context)
    reflection = reflect_property(context)
    if p = properties(context)
      reflection[:properties] = SimpleProperty.reflect context, p
    end
    if a = actions(context)
      reflection[:actions] = SimpleProperty.reflect context, a
    end
    if e = events
      reflection[:events] = SimpleProperty.reflect context, e
    end
    reflection
  end
end
