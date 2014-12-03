describe ApiController do

  let(:connector) { ElasticsearchConnector.make! }
  before { sign_in connector.user }

  it 'should be able to query with empty filter' do
    allow_any_instance_of(ElasticsearchConnector::Type).to receive(:query).and_return([])

    get :data, id: connector.guid, path: "indices/my_index/types/patients", filter: "" # filter: "" mimics ?filter=
    expect(response.status).to eq(200)
  end

  describe 'verboice events' do
    let!(:verboice_connector) { VerboiceConnector.make! user: nil }
    let!(:token) { verboice_connector.generate_secret_token! }

    it 'should validate authenticity token' do
      request.env["RAW_POST_DATA"] = "{}"
      request.headers["X-InSTEDD-Hub-Token"] = "#{token}_invalid"

      post :notify, id: verboice_connector.guid, path: "projects/1/call_flows/6/$events/call_finished"
      expect(response.status).to eq(401)
    end

    it "should enqueue a CallTask" do
      data = {"project_id"=>1, "call_flow_id"=>6, "address"=>"17772632588", "vars"=>{"age"=>"20"}}.to_json
      request.env["RAW_POST_DATA"] = data
      request.headers["X-InSTEDD-Hub-Token"] = token
      path = "projects/1/call_flows/6/$events/call_finished"

      expect(Resque).to receive(:enqueue_to).with(:hub, Connector::NotifyJob, verboice_connector.id, path, data)

      post :notify, id: verboice_connector.guid, path: path
    end

    it "should not fail if raw post data is empty" do
      request.env["RAW_POST_DATA"] = nil
      request.headers["X-InSTEDD-Hub-Token"] = token
      path = "projects/1/call_flows/6/$events/call_finished"

      expect(Resque).to receive(:enqueue_to).with(:hub, Connector::NotifyJob, verboice_connector.id, path, "{}")

      post :notify, id: verboice_connector.guid, path: path
    end
  end

end
