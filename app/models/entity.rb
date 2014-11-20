module Entity
  abstract :label, :sub_path
  attr_reader :parent

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

  def query(query_url_proc, current_user, filters)
    if p = properties
      Hash[p.map do |k, v|
        if v.is_a?(EntitySet)
          [k, query_url_proc.call(v.path)]
        else
          [k, v.value]
        end
      end]
    end
  end

  def reflect(reflect_url_proc, user)
    reflection = {}
    if p = properties
      reflection[:properties] = Hash[p.map do |k, v|
        h = {label: v.label, type: v.type}
        if v.path
          h[:path] = v.path
          if reflect_path = v.reflect_path
            h[:reflect_url] = reflect_url_proc.call(reflect_path)
          end
        end
        [k, h]
      end]
    end
    if a = actions(user)
      reflection[:actions] = Hash[a.map do |k, v|
        [k, {label: v.label, path: v.path, reflect_url: reflect_url_proc.call(v.path)}]
      end]
    end
    if e = events
      reflection[:events] = Hash[e.map do |k, v|
        [k, {label: v.label, path: v.path, reflect_url: reflect_url_proc.call(v.path)}]
      end]
    end
    reflection
  end
end
