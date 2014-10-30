class ONAConnector < Connector
  include Entity
  store_accessor :settings, :url

  def properties
    {"Forms" => Forms.new(self)}
  end

  private

  class Forms
    include EntitySet

    def initialize(connector)
      @connector = connector
    end

    def path
      "/Forms"
    end

    def entities
      @entities ||= begin
        forms = JSON.parse(RestClient.get("#{@connector.url}/api/v1/forms.json"))
        forms.map { |form| Form.new(@connector, form["formid"], form["title"]) }
      end
    end

    def find_entity(id)
      Form.new(@connector, id)
    end
  end

  class Form
    include Entity

    def initialize(connector, id, name = nil)
      @connector = connector
      @id = id
      @name = name
    end

    def name
      @name
    end

    def path
      "/Forms/#{@id}"
    end

    def form_definition
      @form_definition ||= begin
        JSON.parse(RestClient.get("#{@connector.url}/api/v1/forms/#{@id}/form.json"))
      end
    end

    def events
      ["new_data"]
    end

    def reflect_event(event)
      case event
      when "new_data"
        form_definition["children"]
      end
    end

  end

end
