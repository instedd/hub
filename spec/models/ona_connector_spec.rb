describe ONAConnector do
  describe "lookup" do
    let(:connector) { ONAConnector.new url: "http://example.com" }

    it "finds root" do
      expect(connector.lookup []).to be(connector)
    end

    it "reflects on root" do
      expect(connector.reflect).to eq({
        properties: {
          "forms" => {
            name: "Forms",
            kind: :entity_set,
            path: "/forms",
          }
        }
      })
    end

    it "lists forms" do
      allow(RestClient).to receive(:get).
                           with("http://example.com/api/v1/forms.json").
                           and_return(%([{"formid": 1, "title": "Form 1"}]))

      forms = connector.lookup %w(forms)
      expect(forms.reflect).to eq({
        entities: [
          {
            name: "Form 1",
            kind: :entity,
            path: "/forms/1",
          }
        ]
      })
    end

    it "reflects on form" do
      form = connector.lookup %w(forms 1)
      expect(form.reflect).to eq({
        events: {
          "new_data" => {
            name: "New data",
            path: "/forms/1/$events/new_data",
          }
        }
      })
    end

    # it "reflects form new_data event" do
    #   form = connector.lookup %w(forms 1)
    #   expect(form.reflect).to eq({events: %w(new_data)})
    # end
  end
end
