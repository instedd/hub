describe ApiController do

  let(:connector) { ElasticsearchConnector.make! }
  before { sign_in connector.user }

  it 'should be able to query with empty filter' do
    allow_any_instance_of(ElasticsearchConnector::Type).to receive(:query).and_return([])

    get :data, id: connector.guid, path: "indices/my_index/types/patients", filter: "" # filter: "" mimics ?filter=
    expect(response.status).to eq(200)
  end

end
