describe EventHandlersController do
  let(:user)      { User.make! }
  let(:connector) { TestConnector.create! name: "connector", user: user }
  before          { sign_in user }

  it "creates event handler" do
    task = {
      event: {connector: connector.guid, path: connector.events["event"].path}.to_json,
      action: {connector: connector.guid, path: connector.actions(context)["action"].path}.to_json,
      binding: {}.to_json
    }
    post :create, task: task, event_handler: {name: "name"}

    handler = EventHandler.last
    expect(handler).to be
    expect(handler.event).to eq("$events/event")
    expect(handler.action).to eq("$actions/action")
    expect(handler.connector_id).to eq(connector.id)
    expect(handler.target_connector_id).to eq(connector.id)
    expect(handler.user_id).to eq(user.id)
    expect(handler.name).to eq("name")
    expect(handler.binding).to eq({})
  end

  class TestConnector < Connector
    include Entity

    def events
      { "event" => TestEvent.new(self) }
    end

    def actions(context)
      context.user # This call just makes sure the context is correctly passed
      { "action" => TestAction.new(self) }
    end

    class TestEvent
      include Event
      def sub_path; "event"; end
    end

    class TestAction
      include Action
      def sub_path; "action"; end
    end
  end
end
