module EntitySet
  extend ActiveSupport::Concern

  attr_reader :parent

  abstract :path, :label
  def reflect_entities(context)
    query({}, context, page: 1, page_size: 1000)[:items]
  end

  def self.included(mod)
    mod.delegate :connector, to: :parent unless mod.method_defined?(:connector)
  end

  def lookup(path, context)
    return self if path.empty?
    entity_id = path.shift

    case entity_id
    when "$actions"
      ActionsNode.new(self).lookup(path, context)
    when "$events"
      EventsNode.new(self).lookup(path, context)
    else
      find_entity(entity_id, context).lookup(path, context)
    end
  end

  def reflect_path
    path
  end

  def actions(context)
    actions = Hash.new
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

  def filters(context)
    (entity_properties(context) || {}).keys
  end

  def protocols
    self.class.protocols
  end

  abstract def query(filters, context, options)
  end
  abstract def insert(properties, user)
  end
  abstract def update(filters, properties, user)
  end
  abstract def delete filters, user
  end

  def entity_properties(context)
  end

  def reflect_property(context)
    reflection = {}
    reflection[:label] = label
    reflection[:type] = node_type
    reflection[:path] = path
    reflection[:reflect_url] = context.reflect_url(reflect_path) if reflect_path
    reflection
  end

  def reflect(context)
    reflection = reflect_property context
    if properties = entity_properties(context)
      reflection[:entity_definition] = {}
      reflection[:entity_definition][:properties] = SimpleProperty.reflect context, properties
    end
    reflection[:protocol] = protocols unless protocols.empty?
    if e = reflect_entities(context)
      reflection[:entities] = e.map { |entity| entity.reflect_property(context) }
    end
    if a = actions(context)
      reflection[:actions] = SimpleProperty.reflect context, a
    end
    if e = events
      reflection[:events] = SimpleProperty.reflect context, e
    end
    reflection
  end

  def raw(context)
    {
      label: label,
      path: path,
      data_url: context.data_url(path)
    }
  end

  def node_type
    :entity_set
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

    def args(context)
      {
        properties: ComposedProperty.new(@parent.entity_properties(context)).reflect_property(context)
      }
    end

    def invoke(args, context)
      @parent.insert args["properties"], context
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

    def args(context)
      {
        filters: ComposedProperty.new(@parent.entity_properties(context).select do |key|
          @parent.filters(context).include? key
        end).reflect_property(context),
        properties: ComposedProperty.new(@parent.entity_properties(context)).reflect_property(context)
      }
    end

    def invoke(args, context)
      @parent.update args["filters"], args["properties"], context
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

    def args(context)
      {
        filters: ComposedProperty.new(@parent.entity_properties(context).select do |key|
          @parent.filters(context).include? key
        end).reflect_property(context)
      }
    end

    def invoke(args, context)
      @parent.delete args["filters"], context
    end
  end
end
