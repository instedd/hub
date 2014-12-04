describe ACTConnector do

  describe "lookup" do
    let(:connector) { ACTConnector.make url: "http://act.instedd.org" }
    let(:user) { User.make }

    it "has guid when saved" do
      connector.save!
      expect(connector.guid).to_not be_nil
    end

    it "finds root" do
      expect(connector.lookup [], user).to be(connector)
    end

    it "reflects on root" do
      expect(connector.reflect(context)).to eq({
        label: connector.name,
        path: "",
        reflect_url: "http://server/api/reflect/connectors/1",
        type: :entity,
        properties: {
          "cases" => {
            label: "Cases",
            type: :entity_set,
            path: "cases",
            reflect_url: "http://server/api/reflect/connectors/1/cases"
          }
        }
      })
    end

    it "doesn't list individual cases" do
      # empty entity list should be returned without needing to contact the API
      cases = connector.lookup %w(cases), user
      listed_entities = cases.reflect(context)[:entities]
      expect(listed_entities).to be(nil)
    end

    describe "new case event" do

      it "reflects event" do
        cases = connector.lookup %w(cases), user
        listed_events = cases.reflect(context)[:events]
        expect(listed_events["new_case"]).to eq({
            :label => "New case",
            :path => "cases/$events/new_case",
            :reflect_url => "http://server/api/reflect/connectors/1/cases/$events/new_case"
        })
      end

      it "includes parameters for poirot call" do
        new_case_event = connector.lookup %w(cases $events new_case), user
        expected_args = [:id, :patient_name, :patient_phone_number, :patient_age, :patient_gender, :dialect_code, :symptoms]
        expect(new_case_event.args(user).keys).to match_array(expected_args)
      end

    end

    describe "case confirmed sick event" do

      it "reflects event" do
        cases = connector.lookup %w(cases), user
        listed_events = cases.reflect(context)[:events]
        expect(listed_events["case_confirmed_sick"]).to eq({
            :label => "Case confirmed sick",
            :path => "cases/$events/case_confirmed_sick",
            :reflect_url => "http://server/api/reflect/connectors/1/cases/$events/case_confirmed_sick"
        })
      end

    end

    describe "update case task" do

      it "reflects task" do
        cases = connector.lookup %w(cases), user
        listed_actions = cases.reflect(context)[:actions]
        expect(listed_actions).to eq({
          "update_case" => {
            :label => "Update case",
            :path => "cases/$actions/update_case",
            :reflect_url => "http://server/api/reflect/connectors/1/cases/$actions/update_case"
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

        expect(RestClient).to receive(:put) do |url, body, headers|
          expect(url).to eq(update_url)
          expect(body).to be_nil
          expect(headers["Authorization"]).to eq("Token token=\"#{connector.access_token}\"")
        end

        action = connector.lookup %w(cases $actions update_case), user
        action.invoke({'case_id' => case_id, 'is_sick' => true}, user)
      end

    end

  end
end
