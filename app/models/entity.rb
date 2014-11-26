module Entity
  attr_reader :parent
  abstract :label, :sub_path

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
      properties[property_name].lookup(path, user)
    end
  end

  def reflect_path
    path
  end

  def path
    "#{parent.path}/#{sub_path}"
  end

  def properties
  end

  def actions(user)
  end

  def events
  end

  def raw(data_url_proc, current_user)
    if p = properties
      Hash[p.map do |k, v|
        if v.is_a?(EntitySet)
          [k, data_url_proc.call(v.path)]
        else
          [k, v.value]
        end
      end]
    end
  end

  def reflect_property(reflect_url_proc)
    {
      label: label,
      path: path,
      reflect_url: reflect_url_proc.call(path)
    }
  end

  def reflect(reflect_url_proc, user)
    reflection = {}
    reflection[:properties] = SimpleProperty.reflect reflect_url_proc, properties, user if properties
    if a = actions(user)
      reflection[:actions] = Hash[a.map do |k, v|
        [k, v.reflect_property(reflect_url_proc)]
      end]
    end
    if e = events
      reflection[:events] = Hash[e.map do |k, v|
        [k, v.reflect_property(reflect_url_proc)]
      end]
    end
    reflection
  end
end
