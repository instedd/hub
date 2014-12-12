describe GoogleFusionTablesConnector do

  describe "query" do
    it "should generate query url" do
      table = GoogleFusionTablesConnector::Table.new nil, "1234", "name", nil
      url = table.generate_query_url({name: 'paul', age: 2})
      expect(url).to eq("https://www.googleapis.com/fusiontables/v2/query?sql=SELECT+%2A+FROM+1234+WHERE+name%3D%27paul%27+AND+age%3D%272%27")
    end

  end

end
