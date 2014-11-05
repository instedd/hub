class ONAConnector < Connector
  include Entity
  store_accessor :settings, :url
  validates_presence_of :url

  def properties
    {"forms" => Forms.new(self)}
  end

  private

  class Forms
    include EntitySet

    def initialize(parent)
      @parent = parent
    end

    def path
      "forms"
    end

    def label
      "Forms"
    end

    def entities
      @entities ||= begin
        forms ||= JSON.parse(RestClient.get("#{connector.url}/api/v1/forms.json"))
        forms.map { |form| Form.new(self, form["formid"], form) }
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
    attr_reader :id

    def initialize(parent, id, form = nil)
      @parent = parent
      @id = id
      @form = form
    end

    def properties
      @form ||= JSON.parse(RestClient.get("#{connector.url}/api/v1/forms/#{@id}.json"))
      {
        "id" => SimpleProperty.new("Id", :integer, @id)
      }
    end

    def label
      @form["title"]
    end

    def sub_path
      id
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

    def label
      "New data"
    end

    def sub_path
      "new_data"
    end

    def poll
      max_id = load_state
      url = "#{connector.url}/api/v1/data/#{parent.id}.json"
      if max_id
        query = %({"_id":{"$gt":#{max_id}}})
        url << %(?query=#{CGI.escape query})
      end

      all_data = JSON.parse(RestClient.get(url))
      form = JSON.parse(RestClient.get("#{connector.url}/api/v1/forms/#{parent.id}/form.json"))
      events = all_data.map do |data|
        output = process_data data, form["children"]
        output["_id"] = data["_id"]
        output
      end
      if events.empty?
        return []
      end

      max_id = events.max_by { |o| o["_id"] }["_id"]
      save_state(max_id)
      events
    end

    def process_data(data, children, prefix = "", output = {})
      children.each do |c|
        data_path = "#{prefix}#{c["name"]}"
        type = c["type"]
        name = c["name"]
        case type
        when "geopoint"
          value = data[data_path]
          if value
            lat, lon = value.split.map(&:to_f)
            output[name] = {lat: lat, lon: lon}
          else
            output[name] = nil
          end
        when "group"
          output[name] ||= sub = {}
          process_data data, c["children"], "#{data_path}/", sub
        when "repeat"
          value = Array(data[data_path])
          output[name] = value.map { |v| process_data(v, c["children"], "#{data_path}/") }
        else
          output[name] = data[data_path]
        end
      end
      output
    end

    def args
      form = JSON.parse(RestClient.get("#{connector.url}/api/v1/forms/#{parent.id}/form.json"))
      args = type_children(form, form["children"])
      args["_id"] = {type: :integer}
      args
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
          {type: {kind: :struct, members: {lat: :float, lon: :float}}}
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
          {type: {kind: :array, item_type: {kind: :struct, members: members}}}
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
