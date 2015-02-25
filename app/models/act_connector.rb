class ACTConnector < Connector
  include Entity
  store_accessor :settings, :url, :access_token

  validates_presence_of :url
  validates_presence_of :access_token

  def human_type
    "ACT"
  end

  def properties(context)
    {"cases" => Cases.new(self)}
  end

  def authorization_header
    "Token token=\"#{access_token}\""
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

    def reflect_entities(context)
    end

    def query(filters, context, options)
      {items: []}
    end

    def find_entity(id, context)
      raise "Individual cases cannot be accessed through the connector"
    end

    def events
      {
        "new_case" => NewCaseEvent.new(self),
        "case_confirmed_sick" => CaseConfirmedSickEvent.new(self)
      }
    end

    def actions(context)
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
      query_params = since_id.present? ? { since_id: since_id } : {}
      url = "#{connector.url}/api/v1/cases/?#{query_params.to_query}"

      headers = { "Authorization" => connector.authorization_header }

      cases = JSON.parse(RestClient.get(url, headers))

      # assumes cases are sorted by date
      save_state(cases.last["id"]) unless cases.empty?

      cases
    end

    def args(context)
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

  class CaseConfirmedSickEvent
    include Event

    def initialize(parent)
      @parent = parent
    end

    def label
      "Case confirmed sick"
    end

    def sub_path
      "case_confirmed_sick"
    end

    def poll
      since_id = load_state

      query_params = { notification_type: :case_confirmed_sick }
      query_params[:since_id] = since_id if since_id.present?
      url = "#{connector.url}/api/v1/notifications/?#{query_params.to_query}"

      headers = { "Authorization" => connector.authorization_header }

      notifications = JSON.parse(RestClient.get(url, headers))
      # assumes notifications are sorted by date
      save_state(notifications.last["id"]) unless notifications.empty?

      return notifications.map { |n| n["metadata"] }
    end

    def args(context)
      {
        id: { type: :integer },
        patient_name: { type: :string },
        patient_phone_number: { type: :string },
        patient_age: { type: :string },
        patient_gender: { type: {kind: :enum, value_type: :string, members: [
          {value: "M", label: "Male" },
          {value: "F", label: "Female" },
        ]}},
        supervisor_name: { type: :string },
        supervisor_phone_number: { type: :string },
        dialect_code: { type: :string }
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

    def args(context)
      {
        case_id: {
          type: "string",
          label: "Case ID"
        },
        is_sick: {
          type: "boolean",
          label: "Is patient sick?"
        },
        family_sick: {
          type: "boolean",
          label: "Is any family member sick?"
        },
        community_sick: {
          type: "boolean",
          label: "Is any community member sick?"
        },
        symptoms: {
          type: {
            kind: :struct,
            open: true
          }
        }
      }
    end

    def invoke(args, context)
      query_params = { sick: args['is_sick'], family_sick: args['family_sick'], community_sick: args['community_sick'] }
      symptoms = args['symptoms'] || {}
      query_params = symptoms.keys.inject(query_params) { |params, field|
        query_params[field] = symptoms[field]
        query_params
      }
      url = "#{connector.url}/api/v1/cases/#{args['case_id']}/?#{query_params.to_query}"
      headers = { "Authorization" => connector.authorization_header }
      RestClient.put(url, nil, headers)
    end

  end

end
