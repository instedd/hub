describe CallbacksController do
  include Devise::TestHelpers

  before(:each) do
    sign_in user
  end

  let!(:user) { User.make }

  it 'should find verboice connector when calling execute' do
    verboice_connector = VerboiceConnector.make! shared: true
    verboice_connector_2 = VerboiceConnector.make! shared: false

    post :execute, {connector: 'verboice'}
    assigned_connector = controller.connector

    expect(assigned_connector).to eq(verboice_connector)
  end
end
