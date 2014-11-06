describe ONAConnector do
  describe "lookup" do
    let(:connector) { ONAConnector.make url: "http://example.com" }
    let(:url_proc) { ->(path) { "http://server/#{path}" }}
    let(:user) { User.make }

    it "has guid when saved" do
      connector.save!
      expect(connector.guid).to_not be_nil
    end

    it "finds root" do
      expect(connector.lookup []).to be(connector)
    end

    it "reflects on root" do
      expect(connector.reflect(url_proc, user)).to eq({
        properties: {
          "forms" => {
            label: "Forms",
            type: :entity_set,
            path: "forms",
            reflect_url: "http://server/forms"
          }
        }
      })
    end

    it "lists forms" do
      stub_request(:get, "http://example.com/api/v1/forms.json").
        to_return(status: 200, body: %([{"formid": 1, "title": "Form 1"}]), headers: {})

      forms = connector.lookup %w(forms)
      expect(forms.reflect(url_proc, user)).to eq({
        entities: [
          {
            label: "Form 1",
            path: "forms/1",
            reflect_url: "http://server/forms/1"
          }
        ]
      })
    end

    it "reflects on form" do
      stub_request(:get, "http://example.com/api/v1/forms/1.json").
        to_return(status: 200, body: %({"formid": 1, "title": "Form 1"}), headers: {})

      form = connector.lookup %w(forms 1)
      expect(form.reflect(url_proc, user)).to eq({
        properties: {
          "id" => {
            label: "Id",
            type: :integer
          }
        },
        events: {
          "new_data" => {
            label: "New data",
            path: "forms/1/$events/new_data",
            reflect_url: "http://server/forms/1/$events/new_data"
          }
        }
      })
    end

    # it "reflects form new_data event" do
    #   form = connector.lookup %w(forms 1)
    #   expect(form.reflect(url_proc)).to eq({events: %w(new_data)})
    # end
  end
end
