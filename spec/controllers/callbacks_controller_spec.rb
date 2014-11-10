describe CallbacksController do

  it 'should validate authenticity token' do
    post :execute, {connector: 'verboice', token: 'invalid'}
    expect(response.status).to eq(401)

  end

  it 'should find verboice connector when calling execute' do
    verboice_connector = VerboiceConnector.make! shared: true
    verboice_connector_2 = VerboiceConnector.make! shared: false

    post :execute, {connector: 'verboice', token: Settings.authentication_token}
    assigned_connector = controller.connector

    expect(assigned_connector).to eq(verboice_connector)
    expect(response.status).to eq(200)
  end
end
