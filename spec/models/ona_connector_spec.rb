describe ONAConnector do
  describe "lookup" do
    let(:connector) { ONAConnector.new url: "http://example.com" }
    let(:url_proc) { ->(path) { "http://server/#{path}" }}

    it "finds root" do
      expect(connector.lookup []).to be(connector)
    end

    it "reflects on root" do
      expect(connector.reflect(url_proc)).to eq({
        properties: {
          "forms" => {
            label: "Forms",
            type: {
              kind: :entity_set,
              entity_type: {
                kind: :struct,
                members: []
              }
            },
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
      form = connector.lookup %w(forms 1)
      expect(form.reflect(url_proc)).to eq({
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
