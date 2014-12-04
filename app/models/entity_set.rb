module EntitySet
  extend ActiveSupport::Concern

  attr_reader :parent

  abstract :path, :label
  def reflect_entities(user)
    query({}, user, page: 1, page_size: 1000)
  end

  def self.included(mod)
    mod.delegate :connector, to: :parent unless mod.method_defined?(:connector)
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
    actions = Hash.new
    if protocols.include? :query
      actions["query"] = self.class::QueryAction.new(self)
    end
    if protocols.include? :insert
      actions["insert"] = self.class::InsertAction.new(self)
    end
    if protocols.include? :update
      actions["update"] = self.class::UpdateAction.new(self)
    end
    if protocols.include? :delete
      actions["delete"] = self.class::DeleteAction.new(self)
    end
    actions.presence
  end

  def events
  end

  module ClassMethods
    def protocol(*methods)
      protocols.concat methods
    end
    def protocols
      @protocols ||= [:query]
    end
  end

  def filters(user)
    (entity_properties(user) || {}).keys
  end

  def protocols
    self.class.protocols
  end

  abstract def query(filters, current_user, options)
  end

  def entity_properties(user)
  end

  def reflect_property reflect_url_proc, user
    reflection = {}
    reflection[:label] = label
    reflection[:type] = node_type
    reflection[:path] = path
    reflection[:reflect_url] = reflect_url_proc.call(reflect_path) if reflect_path
    reflection
  end

  def reflect(reflect_url_proc, user)
    reflection = reflect_property reflect_url_proc, user
    if properties = entity_properties(user)
      reflection[:entity_definition] = {}
      reflection[:entity_definition][:properties] = SimpleProperty.reflect reflect_url_proc, properties, user
    end
    reflection[:protocol] = protocols unless protocols.empty?
    if e = reflect_entities(user)
      reflection[:entities] = e.map { |entity| entity.reflect_property(reflect_url_proc, user) }
    end
    if a = actions(user)
      reflection[:actions] = SimpleProperty.reflect reflect_url_proc, a, user
    end
    if e = events
      reflection[:events] = SimpleProperty.reflect reflect_url_proc, e, user
    end
    reflection
  end

  def raw(data_url_proc, current_user)
    {
      label: label,
      path: path,
      data_url: data_url_proc.call(path)
    }
  end

  def node_type
    :entity_set
  end

  class QueryAction
    include Action

    def initialize(parent)
      @parent = parent
    end

    def label
      "Query"
    end

    def sub_path
      "query"
    end

    def args(user)
      SimpleProperty.reflect nil, (@parent.entity_properties(user).select do |key|
        @parent.filters.include? key
      end), user
    end

    def invoke(args, user)
      filter = args.delete(:filter)
      @parent.query filter, current_user, args
    end
  end

  class InsertAction
    include Action

    def initialize(parent)
      @parent = parent
    end

    def label
      "Insert"
    end

    def sub_path
      "insert"
    end

    def args(user)
      {
        properties: SimpleProperty.struct(SimpleProperty.reflect(nil, @parent.entity_properties(user), user))
      }
    end

    def invoke(args, user)
      @parent.insert args["properties"], user
    end
  end

  class UpdateAction
    include Action

    def initialize(parent)
      @parent = parent
    end

    def label
      "Update"
    end

    def sub_path
      "update"
    end

    def args(user)
      {
        filters: SimpleProperty.struct(SimpleProperty.reflect nil, (@parent.entity_properties(user).select do |key|
          @parent.filters(user).include? key
        end), user),
        properties: SimpleProperty.struct(SimpleProperty.reflect(nil, @parent.entity_properties(user), user))
      }
    end

    def invoke(args, user)
      @parent.update args["filters"], args["properties"], user
    end
  end

  class DeleteAction
    include Action

    def initialize(parent)
      @parent = parent
    end

    def label
      "Delete"
    end

    def sub_path
      "delete"
    end

    def args(user)
      {
        filters: SimpleProperty.struct(SimpleProperty.reflect nil, (@parent.entity_properties(user).select do |key|
          @parent.filters(user).include? key
        end), user)
      }
    end

    def invoke(args, user)
      @parent.delete args["filters"], user
    end
  end
end
