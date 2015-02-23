describe ONAConnector do
  describe "lookup" do
    let(:connector) { ONAConnector.make url: "http://example.com" }
    let(:user) { User.make }

    it "has guid when saved" do
      connector.save!
      expect(connector.guid).to_not be_nil
    end

    it "finds root" do
      expect(connector.lookup [], context).to be(connector)
    end

    it "reflects on root" do
      expect(connector.reflect(context)).to eq({
        label: connector.name,
        path: "",
        reflect_url: "http://server/api/reflect/connectors/1",
        type: :entity,
        properties: {
          "forms" => {
            label: "Forms",
            type: :entity_set,
            path: "forms",
            reflect_url: "http://server/api/reflect/connectors/1/forms"
          }
        }
      })
    end

    it "lists forms" do
      stub_request(:get, "http://example.com/api/v1/forms.json").
        to_return(status: 200, body: %([{"formid": 1, "title": "Form 1"}]), headers: {})

      forms = connector.lookup %w(forms), context
      expect(forms.reflect(context)).to eq({
        label: "Forms",
        path: "forms",
        reflect_url: "http://server/api/reflect/connectors/1/forms",
        type: :entity_set,
        protocol: [:query],
        entities: [
          {
            label: "Form 1",
            path: "forms/1",
            type: :entity,
            reflect_url: "http://server/api/reflect/connectors/1/forms/1"
          }
        ]
      })
    end

    it "reflects on form" do
      stub_request(:get, "http://example.com/api/v1/forms/1.json").
        to_return(status: 200, body: %({"formid": 1, "title": "Form 1"}), headers: {})

      form = connector.lookup %w(forms 1), context
      expect(form.reflect(context)).to eq({
        label: "Form 1",
        path: "forms/1",
        reflect_url: "http://server/api/reflect/connectors/1/forms/1",
        type: :entity,
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
            reflect_url: "http://server/api/reflect/connectors/1/forms/1/$events/new_data"
          }
        }
      })
    end

    class ONAMockAction
      attr_reader :connector

      def initialize(connector)
        @connector
      end

      def path
        "foo"
      end
    end

    it "reflects form new_data event" do
      allow_any_instance_of(EventHandler).to receive(:notify_action_created)
      allow_any_instance_of(ONAConnector::NewDataEvent).to receive(:poll)
      allow_any_instance_of(ONAConnector::NewDataEvent).to receive(:load_state)

      event = connector.lookup %w(forms 1 $events new_data), context
      handler = event.subscribe(ONAMockAction.new(connector), "binding", RequestContext.new(user))
      expect(handler).to be_a(EventHandler)
    end
  end
end
