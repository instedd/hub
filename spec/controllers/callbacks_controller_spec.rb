describe CallbacksController do
  describe 'verboice events' do
    let!(:verboice_connector) { VerboiceConnector.make! user: nil }
    let!(:token) { verboice_connector.generate_secret_token! }

    it 'should validate authenticity token' do
      request.headers["X-InSTEDD-Hub-Token"] = "#{token}_invalid"

      post :enqueue, { connector: 'verboice', event: 'call' }
      expect(response.status).to eq(401)
    end

    it 'should find verboice shared connector when calling enqueue' do
      expect(Resque).to receive(:enqueue_to)

      verboice_connector_2 = VerboiceConnector.make!

      request.env["RAW_POST_DATA"] = "{}"
      request.headers["X-InSTEDD-Hub-Token"] = token

      post :enqueue, { connector: 'verboice', event: 'call' }
      assigned_connector = controller.connector

      expect(assigned_connector).to eq(verboice_connector)
      expect(response.status).to eq(200)
    end

    it "should enqueue a CallTask" do
      data = {"project_id"=>2, "call_flow_id"=>2, "address"=>"17772632588", "vars"=>{"age"=>"20"}}.to_json
      request.env["RAW_POST_DATA"] = data
      request.headers["X-InSTEDD-Hub-Token"] = token
      expect(Resque).to receive(:enqueue_to).with(:hub, VerboiceConnector::CallTask, verboice_connector.id, data)

      post :enqueue, { connector: 'verboice', event: 'call'}
    end

    it "should not fail if raw post data is empty" do
      request.env["RAW_POST_DATA"] = nil
      request.headers["X-InSTEDD-Hub-Token"] = token
      expect(Resque).to receive(:enqueue_to).with(:hub, VerboiceConnector::CallTask, verboice_connector.id, "{}")
      post :enqueue, { connector: 'verboice', event: 'call'}
    end
  end
end
