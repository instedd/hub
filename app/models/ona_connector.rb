class ONAConnector < Connector
  include Entity
  store_accessor :settings, :url

  def properties
    {"forms" => Forms.new(self)}
  end

  def connector
    self
  end

  private

  class Forms
    include EntitySet

    delegate :connector, to: :@parent

    def initialize(parent)
      @parent = parent
    end

    def path
      "forms"
    end

    def label
      "Forms"
    end

    def type
      {
        kind: :entity_set,
        entity_type: {
          kind: :struct,
          members: []
        }
      }
    end

    def entities
      @entities ||= begin
        forms ||= JSON.parse(RestClient.get("#{connector.url}/api/v1/forms.json"))
        forms.map { |form| Form.new(self, form["formid"], form["title"]) }
      end
    end

    def reflect_entities
      entities
    end

    def find_entity(id)
      Form.new(self, id)
    end
  end

  class Form
    include Entity

    delegate :connector, to: :@parent

    attr_reader :id

    def initialize(parent, id, name = nil)
      @parent = parent
      @id = id
      @name = name
    end

    def label
      @name
    end

    def path
      "#{@parent.path}/#{@id}"
    end

    def events
      {
        "new_data" => NewDataEvent.new(self)
      }
    end
  end

  class NewDataEvent
    include Event

    def initialize(parent)
      @parent = parent
    end

    delegate :connector, to: :@parent

    def label
      "New data"
    end

    def path
      "#{@parent.path}/$events/new_data"
    end

    def args
      form = JSON.parse(RestClient.get("#{connector.url}/api/v1/forms/#{@parent.id}/form.json"))
      type_children(form, form["children"])
    end

    def type_children(form, children)
      args = {}
      children.each do |c|
        type = case c["type"]
        when "date"
          {type: :date}
        when "start"
          {type: :datetime, label: "Start"}
        when "end"
          {type: :datetime, label: "End"}
        when "today"
          {type: :date, label: "Today"}
        when "datetime"
          {type: :datetime}
        when "deviceid"
          {type: :string}
        when "geopoint"
          {type: {kind: :struct, members: {x: :float, y: :float}}}
        when "select one"
          members = ona_children(form, c).map { |m| {value: m["name"], label: ona_label(m) } }
          {type: {kind: :enum, value_type: :string, members: members}}
        when "select all that apply"
          members = ona_children(form, c).map { |m| {value: m["name"], label: ona_label(m) } }
          {type: {kind: :array, item_type: {kind: :enum, value_type: :string, members: members}}}
        when "group"
          members = type_children(form, c["children"])
          {type: {kind: :struct, members: members}} if members.any?
        when "text"
          {type: :string}
        when "integer"
          {type: :integer}
        when "decimal"
          {type: :float}
        when "calculate"
          {type: :string}
        when "repeat"
          members = type_children(form, c["children"])
          {type: :array, item_type: {kind: :struct, members: members}}
        when "note"
          # skip
        else
          raise "Unsupported ONA type: #{c["type"]}"
        end
        if type
          type[:label] ||= ona_label(c)
          args[c["name"]] = type
        end
      end
      args
    end

    def ona_label(obj)
      label = obj["label"]
      if label.is_a?(Hash)
        label["English"]
      else
        label
      end
    end

    def ona_children(form, obj)
      obj["children"] || form["choices"][obj["itemset"]]
    end
  end
end
