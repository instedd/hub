describe CallbacksController do
  it 'should validate authenticity token' do
    post :enqueue, { connector: 'verboice', token: 'invalid', event: 'call' }
    expect(response.status).to eq(401)
  end

  describe 'verboice events' do
    let!(:verboice_connector) { VerboiceConnector.make! user: nil }

    it 'should find verboice shared connector when calling enqueue' do
      verboice_connector_2 = verboice_connector_2 = VerboiceConnector.make!

      post :enqueue, { connector: 'verboice', token: Settings.authentication_token, event: 'call' }
      assigned_connector = controller.connector

      expect(assigned_connector).to eq(verboice_connector)
      expect(response.status).to eq(200)
    end

    it "should enqueue a CallTask" do
      #Remove all tasks from the queue
      Resque.dequeue(VerboiceConnector::CallTask)

      post :enqueue, { connector: 'verboice', token: Settings.authentication_token, event: 'call' }
      expect(VerboiceConnector::CallTask.count_queued_tasks).to eq(1)
    end
  end
end
