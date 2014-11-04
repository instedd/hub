module Entity
  def lookup(path)
    return self if path.empty?
    property_name = path.shift

    case property_name
    when "$actions"
      ActionsNode.new(self).lookup(path)
    when "$events"
      EventsNode.new(self).lookup(path)
    else
      properties[property_name].lookup(path)
    end
  end

  def reflect_path
    path
  end

  def properties
  end

  def actions
  end

  def events
  end

  def query(query_url_proc)
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

  def reflect(reflect_url_proc)
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
    if a = actions
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