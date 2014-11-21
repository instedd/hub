describe CallbacksController do
  it 'should validate authenticity token' do
    post :enqueue, { connector: 'verboice', token: 'invalid', event: 'call' }
    expect(response.status).to eq(401)
  end

  describe 'verboice events' do
    let!(:verboice_connector) { VerboiceConnector.make! user: nil }

    it 'should find verboice shared connector when calling enqueue' do
      expect(Resque).to receive(:enqueue_to)

      verboice_connector_2 = verboice_connector_2 = VerboiceConnector.make!

      post :enqueue, { connector: 'verboice', token: Settings.authentication_token, event: 'call' }
      assigned_connector = controller.connector

      expect(assigned_connector).to eq(verboice_connector)
      expect(response.status).to eq(200)
    end

    it "should enqueue a CallTask" do
      data = {"project_id"=>2, "call_flow_id"=>2, "address"=>"17772632588", "vars"=>{"age"=>"20"}}.to_json
      request.env["RAW_POST_DATA"] = data
      expect(Resque).to receive(:enqueue_to).with(:hub, VerboiceConnector::CallTask, verboice_connector.id, data)

      post :enqueue, { connector: 'verboice', token: Settings.authentication_token, event: 'call'}
    end
  end
end
