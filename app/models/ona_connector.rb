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
      "/forms"
    end

    def name
      "Forms"
    end

    def entities
      @entities ||= begin
        forms = JSON.parse(RestClient.get("#{connector.url}/api/v1/forms.json"))
        forms.map { |form| Form.new(self, form["formid"], form["title"]) }
      end
    end

    def find_entity(id)
      Form.new(self, id)
    end
  end

  class Form
    include Entity
    include Evented

    delegate :connector, to: :@parent

    attr_reader :id

    def initialize(parent, id, name = nil)
      @parent = parent
      @id = id
      @name = name
    end

    def name
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

    def name
      "New data"
    end

    def path
      "#{@parent.path}/$events/new_data"
    end

    def args
      JSON.parse(RestClient.get("#{connector.url}/api/v1/forms/#{@parent.id}/form.json"))
    end
  end
end
