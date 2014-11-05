describe ONAConnector do
  describe "lookup" do
    let(:connector) { ONAConnector.make url: "http://example.com" }
    let(:url_proc) { ->(path) { "http://server/#{path}" }}

    it "has guid when saved" do
      connector.save!
      expect(connector.guid).to_not be_nil
    end

    it "finds root" do
      expect(connector.lookup []).to be(connector)
    end

    it "reflects on root" do
      expect(connector.reflect(url_proc)).to eq({
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
      allow(RestClient).to receive(:get).
                           with("http://example.com/api/v1/forms.json").
                           and_return(%([{"formid": 1, "title": "Form 1"}]))

      forms = connector.lookup %w(forms)
      expect(forms.reflect(url_proc)).to eq({
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
      allow(RestClient).to receive(:get).
                           with("http://example.com/api/v1/forms/1.json").
                           and_return(%({"formid": 1, "title": "Form 1"}))

      form = connector.lookup %w(forms 1)
      expect(form.reflect(url_proc)).to eq({
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
