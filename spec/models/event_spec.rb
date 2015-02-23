describe Event do
  class MockPollEvent
    include Event

    attr_reader :connector

    def initialize(connector)
      @connector = connector
    end

    def poll
      [ { "event1" => "foo" } ]
    end

    def path
      "mock/$events/event"
    end
  end

  class MockAction
    attr_reader :connector

    def initialize(connector)
      @connector = connector
    end

    def path
      "mock/$actions/action"
    end

    def invoke(options, user)
    end
  end

  class MockConnector < Connector
    include Entity

    def properties(user)
      {"mock" => MockProperty.new(self)}
    end

    def url
      "foo.bar"
    end
  end

  class MockProperty
    include Entity

    def initialize(parent)
      @parent = parent
    end

    def path
      "mock"
    end

    def actions(user)
      {
        "action" => MockAction.new(self)
      }
    end

    def events
      {
        "event" => MockPollEvent.new(self)
      }
    end
  end


  let(:user) { User.make! }
  let(:event_connector) { MockConnector.create! name: "Event Connector" }
  let(:action_connector) { MockConnector.create! name: "Action Connector" }
  let(:request_context) { RequestContext.new(user) }

  it "subscribes action" do
    event = MockPollEvent.new(event_connector)
    event.subscribe(MockAction.new(action_connector), "some_binding", request_context)

    handlers = EventHandler.all
    expect(handlers.length).to eq(1)

    handler = handlers.first
    expect(handler.connector_id).to eq(event_connector.id)
    expect(handler.event).to eq("mock/$events/event")
    expect(handler.action).to eq("mock/$actions/action")
    expect(handler.poll).to be_truthy
    expect(handler.target_connector_id).to eq(action_connector.id)
    expect(handler.user_id).to eq(user.id)
    expect(handler.binding).to eq("some_binding")
  end

  it "should trigger an action for every queued jobs" do
    event = MockPollEvent.new(event_connector)
    action = MockAction.new(action_connector)
    event.subscribe(action, "some_binding", request_context)

    expect_any_instance_of(MockAction).to receive(:invoke)
    Connector::PollJob.perform(event_connector.id)
  end

  it "shouldn't trigger an action for disabled event handlers" do
    event = MockPollEvent.new(event_connector)
    action = MockAction.new(action_connector)
    handler = event.subscribe(action, "some_binding", request_context)
    handler.enabled = false
    handler.save!

    expect_any_instance_of(MockAction).to_not receive(:invoke)
    Connector::PollJob.perform(event_connector.id)
  end
end
