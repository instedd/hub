module Entity
  attr_reader :parent
  abstract :sub_path

  def node_type
    :entity
  end

  def self.included(mod)
    mod.delegate :connector, to: :parent unless mod.method_defined?(:connector)
  end

  def lookup(path, user)
    return self if path.empty?
    property_name = path.shift

    case property_name
    when "$actions"
      ActionsNode.new(self).lookup(path, user)
    when "$events"
      EventsNode.new(self).lookup(path, user)
    else
      properties(user)[property_name].lookup(path, user)
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

  def properties(user)
  end

  def actions(user)
  end

  def events
  end

  def raw(data_url_proc, current_user)
    if p = properties(current_user)
      Hash[p.map do |k, v|
        if v.is_a?(EntitySet)
          [k, data_url_proc.call(v.path)]
        else
          [k, v.value]
        end
      end]
    end
  end

  def reflect_property(reflect_url_proc, user)
    {
      label: label,
      path: path,
      type: node_type,
      reflect_url: reflect_url_proc.call(path)
    }
  end

  def reflect(reflect_url_proc, user)
    reflection = reflect_property(reflect_url_proc, user)
    reflection[:properties] = SimpleProperty.reflect reflect_url_proc, properties(user), user if properties(user)
    if a = actions(user)
      reflection[:actions] = SimpleProperty.reflect reflect_url_proc, a, user
    end
    if e = events
      reflection[:events] = SimpleProperty.reflect reflect_url_proc, e, user
    end
    reflection
  end
end
