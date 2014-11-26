class ACTConnector < Connector
  include Entity
  store_accessor :settings, :url

  validates_presence_of :url

  def properties
    {"cases" => Cases.new(self)}
  end

  private

  class Cases
    include EntitySet

    def initialize(parent)
      @parent = parent
    end

    def path
      "cases"
    end

    def label
      "Cases"
    end

    def entities(user)
      []
    end

    def find_entity(id, user)
      raise "Individual cases cannot be accessed through the connector"
    end

    def events
      {
        "new_case" => NewCaseEvent.new(self)
      }
    end

    def actions(user)
      {
        "update_case" => UpdateCaseAction.new(self)
      }
    end

  end

  class NewCaseEvent
    include Event

    def initialize(parent)
      @parent = parent
    end

    def label
      "New case"
    end

    def sub_path
      "new_case"
    end

    def poll
      since_id = load_state
      url = "#{connector.url}/api/v1/cases/"
      url += "?since_id=#{since_id}" if since_id.present?
      cases = JSON.parse(RestClient.get(url))

      # assumes cases are sorted by date
      save_state(cases.last["id"]) unless cases.empty?

      cases
    end

    def args(user)
      {
        id: { type: :integer },
        patient_name: { type: :string },
        patient_phone_number: { type: :string },
        patient_age: { type: :string },
        patient_gender: { type: {kind: :enum, value_type: :string, members: [
          {value: "M", label: "Male" },
          {value: "F", label: "Female" },
        ]}},
        dialect_code: { type: :string },
        symptoms: {type: {kind: :array, item_type: :string}},
      }
    end
  end

  class UpdateCaseAction
    include Action

    def initialize(parent)
      @parent = parent
    end

    def label
      "Update case"
    end

    def sub_path
      "update_case"
    end

    def args(user)
      {
        case_id: {
          type: "string",
          label: "Case ID"
        },
        is_sick: {
          type: "boolean",
          label: "Is patient sick?"
        }
      }
    end

    def invoke(args, user)
      url = "#{connector.url}/api/v1/cases/#{args['case_id']}/"
      url += "?sick=#{args['is_sick']}"
      RestClient.put(url, nil)
    end

  end

end
