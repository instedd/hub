describe Api::EventHandlersController do

  let(:user) { User.make! }
  let(:verboice_connector) { VerboiceConnector.make! username: 'jdoe', password: '1234', user: user }
  let(:mbuilder_connector) { MBuilderConnector.make! username: 'jdoe', password: '1234', user: user }

  before(:each) do
    sign_in user

    stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/1.json").
      to_return(status: 200, body: %({
          "id": 2
        }), headers: {})

    stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/1/call_flows/6.json").
      to_return(status: 200, body: %({
          "id": 740,
          "name": "my flow"
        }), headers: {})

    stub_request(:get, "https://jdoe:1234@mbuilder.instedd.org/api/applications/1/actions").
      to_return(status: 200, body: %([
        {
          "id": 2
        }]), headers: {})
  end

  let!(:event_handler) do
    EventHandler.create!(
      connector: verboice_connector,
      event: "projects/1/call_flows/6/$events/call_finished",
      target_connector: mbuilder_connector,
      action: "applications/1/$actions/trigger_2",
      user: user
    )
  end

  it 'lists event handlers' do
    get :index, format: :json

    expect(controller.event_handlers).to eq([event_handler])
  end

  it 'deletes event handlers' do
    delete :destroy, id: event_handler.id

    expect(EventHandler.find_by_id(event_handler.id)).to be_nil
  end

  it 'creates an event handler' do
    data = {
      name: "New api event handler",
      enabled: true,
      event: {
        connector: verboice_connector.guid,
        path: "projects/1/call_flows/6/$events/call_finished"
      },
      action: {
        connector: mbuilder_connector.guid,
        path: "applications/1/$actions/trigger_2"
      },
      binding: {
        type:"struct",
        members: {
           properties: {
              type:"struct",
              members: {
                 phone_number:[
                    "address"
                 ]
              }
           }
        }
      }
    }

    post :create, event_handler: data

    expect(EventHandler.count).to eq(2)
    event_handler = EventHandler.last

    expect(event_handler.name).to eq(data[:name])
    expect(event_handler.enabled).to eq(data[:enabled])
    expect(event_handler.connector_id).to eq(verboice_connector.id)
    expect(event_handler.event).to eq(data[:event][:path])
    expect(event_handler.target_connector_id).to eq(mbuilder_connector.id)
    expect(event_handler.action).to eq(data[:action][:path])
    expect(event_handler.user_id).to eq(user.id)
    expect(event_handler.binding).to eq(data[:binding].with_indifferent_access)
  end

end
