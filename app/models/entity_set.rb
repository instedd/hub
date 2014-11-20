module EntitySet
  abstract :path, :label
  attr_reader :parent

  def self.included(mod)
    mod.delegate :connector, to: :parent unless mod.method_defined?(:connector)
  end

  abstract def entities(user, filters={})
  end

  def lookup(path, user)
    return self if path.empty?
    entity_id = path.shift

    case entity_id
    when "$actions"
      ActionsNode.new(self).lookup(path, user)
    when "$events"
      EventsNode.new(self).lookup(path, user)
    else
      find_entity(entity_id, user).lookup(path, user)
    end
  end

  def reflect_path
    path
  end

  def actions(user)
  end

  def events
  end

  def query(query_url_proc, current_user, filters)
    entities(current_user, filters).map { |e| e.query(query_url_proc, current_user, filters) }
  end

  def insert(insert_url_proc)
  end

  def update(update_url_proc)
  end

  def delete(delete_url_proc)
  end

  def reflect_entities(user)
    entities(user)
  end

  def entity_properties
  end

  def reflect(reflect_url_proc, user)
    reflection = {}
    reflection[:entity_definition] = {}
    reflection[:entity_definition][:properties] = entity_properties if entity_properties
    reflection[:entities] = reflect_entities(user).map do |entity|
      {label: entity.label, path: entity.path, reflect_url: reflect_url_proc.call(entity.path)}
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

  def type
    :entity_set
  end
end
