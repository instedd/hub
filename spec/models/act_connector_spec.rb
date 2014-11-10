describe ACTConnector do

  describe "lookup" do
    let(:connector) { ACTConnector.make url: "http://example.com" }
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

    it "reflects cases new_case event" do
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

    it "includes parameters for poirot call in new case event" do
      new_case_event = connector.lookup %w(cases $events new_case), user
      expect(new_case_event.args(user).keys).to match_array([:patient_name, :patient_phone_number, :patient_age, :patient_gender, :dialect_code, :symptoms])
    end

  end
end
