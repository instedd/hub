describe ACTConnector do

  describe "lookup" do
    let(:connector) { ACTConnector.make url: "http://act.instedd.org" }
    let(:url_proc) { ->(path) { "http://server/#{path}" }}
    let(:user) { User.make }

    it "has guid when saved" do
      connector.save!
      expect(connector.guid).to_not be_nil
    end

    it "finds root" do
      expect(connector.lookup [], user).to be(connector)
    end

    it "reflects on root" do
      expect(connector.reflect(url_proc, user)).to eq({
        properties: {
          "cases" => {
            label: "Cases",
            type: :entity_set,
            path: "cases",
            reflect_url: "http://server/cases"
          }
        }
      })
    end

    it "doesn't list individual cases" do
      # empty entity list should be returned without needing to contact the API
      cases = connector.lookup %w(cases), user
      listed_entities = cases.reflect(url_proc, user)[:entities]
      expect(listed_entities).to be_empty
    end

    describe "new case event" do

      it "reflects event" do
        cases = connector.lookup %w(cases), user
        listed_events = cases.reflect(url_proc, user)[:events]
        expect(listed_events).to eq({
          "new_case" => {
            :label => "New case",
            :path => "cases/$events/new_case",
            :reflect_url => "http://server/cases/$events/new_case"
          }
        })
      end

      it "includes parameters for poirot call" do
        new_case_event = connector.lookup %w(cases $events new_case), user
        expected_args = [:id, :patient_name, :patient_phone_number, :patient_age, :patient_gender, :dialect_code, :symptoms]
        expect(new_case_event.args(user).keys).to match_array(expected_args)
      end

    end

    describe "update case task" do

      it "reflects task" do
        cases = connector.lookup %w(cases), user
        listed_actions = cases.reflect(url_proc, user)[:actions]
        expect(listed_actions).to eq({
          "update_case" => {
            :label => "Update case",
            :path => "cases/$actions/update_case",
            :reflect_url => "http://server/cases/$actions/update_case"
          }
        })
      end

      it "includes parameters for action" do
        action = connector.lookup %w(cases $actions update_case), user
        expect(action.args(user).keys).to match_array([:case_id, :is_sick])
      end

      it "contacts ACT API when performed" do
        case_id = 123
        update_url = "http://act.instedd.org/api/v1/cases/#{case_id}/?sick=true"
        
        expect(RestClient).to receive(:put).with(update_url, nil)

        action = connector.lookup %w(cases $actions update_case), user
        action.invoke({'case_id' => case_id, 'is_sick' => true}, user)
      end

    end

  end
end
