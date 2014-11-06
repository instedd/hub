module EntitySet
  abstract :path, :label
  attr_reader :parent
  delegate :connector, to: :parent

  def lookup(path)
    return self if path.empty?
    entity_id = path.shift

    case entity_id
    when "$actions"
      ActionsNode.new(self).lookup(path)
    when "$events"
      EventsNode.new(self).lookup(path)
    else
      find_entity(entity_id).lookup(path)
    end
  end

  def reflect_path
    path
  end

  def actions
  end

  def events
  end

  def query(query_url_proc)
    entities.map { |e| e.query(query_url_proc) }
  end

  def reflect(reflect_url_proc, user)
    reflection = {}
    reflection[:entities] = entities(user).map do |entity|
      {label: entity.label, path: entity.path, reflect_url: reflect_url_proc.call(entity.path)}
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

  def type
    :entity_set
  end
end
