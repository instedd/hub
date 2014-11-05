describe Event do
  class MockPollEvent
    include Event

    attr_reader :connector

    def initialize(connector)
      @connector = connector
    end

    def poll
    end

    def path
      "mock/event"
    end
  end

  class MockAction
    attr_reader :connector

    def initialize(connector)
      @connector = connector
    end

    def path
      "mock/action"
    end
  end

  let(:user) { User.make! }
  let(:event_connector) { Connector.make! }
  let(:action_connector) { Connector.make! }

  it "subscribes action" do
    event = MockPollEvent.new(event_connector)
    event.subscribe(MockAction.new(action_connector), "some_binding", user)

    handlers = EventHandler.all
    expect(handlers.length).to eq(1)

    handler = handlers.first
    expect(handler.connector_id).to eq(event_connector.id)
    expect(handler.event).to eq("mock/event")
    expect(handler.action).to eq("mock/action")
    expect(handler.poll).to be_truthy
    expect(handler.target_connector_id).to eq(action_connector.id)
    expect(handler.user_id).to eq(user.id)
    expect(handler.binding).to eq("some_binding")
  end
end
