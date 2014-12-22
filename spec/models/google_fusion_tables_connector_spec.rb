describe GoogleFusionTablesConnector do

  describe "query" do
    it "should generate query url" do
      table = GoogleFusionTablesConnector::Table.new nil, "1234", "name", nil
      url = table.generate_query_url({name: 'paul', age: 2})
      expect(url).to eq("https://www.googleapis.com/fusiontables/v2/query?sql=SELECT+%2A+FROM+1234+WHERE+%27name%27%3D%27paul%27+AND+%27age%27%3D%272%27")
    end
  end

  describe "actions" do
    let(:connector) { GoogleFusionTablesConnector.new access_token: '1234'}
    let(:user) { User.make }

    before :each do
      stub_request(:get, "https://www.googleapis.com/fusiontables/v2/tables/1").
         with(:headers => {'Authorization'=>'Bearer 1234'}).
         to_return(:status => 200, :body =>
          %({
           "kind": "fusiontables#table",
           "tableId": "1e7y6mtqv892233322222_bbbbbbbbb_CvWhg9gc",
           "name": "Insects",
           "columns": [
            {
             "kind": "fusiontables#column",
             "columnId": 0,
             "name": "Species",
             "type": "STRING"
            },
            {
             "kind": "fusiontables#column",
             "columnId": 1,
             "name": "Elevation",
             "type": "NUMBER"
            },
            {
             "kind": "fusiontables#column",
             "columnId": 2,
             "name": "Year",
             "type": "DATETIME"
            }
           ],
           "description": "Insect Tracking Information.",
           "isExportable": true}), :headers => {})
    end

    it "should query all values" do
      stub_request(:get, "https://www.googleapis.com/fusiontables/v2/query?sql=SELECT%20*%20FROM%201").
         with(:headers => { 'Authorization'=>'Bearer 1234'}).
         to_return(:status => 200, :body =>
          %({
           "kind": "fusiontables#sqlresponse",
           "columns": [
            "rowid",
            "Product",
            "Inventory"
           ],
           "rows": [
            [
             "1",
             "Amber Bead",
             "1251500558"
            ],
            [
             "201",
             "Black Shoes",
             "356"
            ],
            [
             "401",
             "White Shoes",
             "100"
            ]
           ]
          }), :headers => {})

      table = connector.lookup_path "tables/1", user
      res = table.query({}, nil, nil)
      expect(res.map {|r|r.properties(nil)}). to eq([
        {"Species"=>"1", "Elevation"=>"Amber Bead", "Year"=>"1251500558"},
        {"Species"=>"201", "Elevation"=>"Black Shoes", "Year"=>"356"},
        {"Species"=>"401", "Elevation"=>"White Shoes", "Year"=>"100"}])
    end

    it "should query with conditions" do
      stub_request(:get, "https://www.googleapis.com/fusiontables/v2/query?sql=SELECT%20*%20FROM%201%20WHERE%20'Product'='Black%20Shoes'%20AND%20'Inventory'='356'").
       with(:headers => {'Authorization'=>'Bearer 1234'}).
       to_return(:status => 200, :body =>
        %({
           "kind": "fusiontables#sqlresponse",
           "columns": [
            "rowid",
            "Product",
            "Inventory"
           ],
          "rows": [
            [
             "201",
             "Black Shoes",
             "356"
            ]
          ]
          }), :headers => {})

      table = connector.lookup_path "tables/1", user
      res = table.query({"Product"=>"Black Shoes","Inventory"=>"356"}, nil, nil)
      expect(res.map {|r|r.properties(nil)}). to eq([
        {"Species"=>"201", "Elevation"=>"Black Shoes", "Year"=>"356"}])
    end

    it "should insert a row" do
      stub_request(:post, "https://www.googleapis.com/fusiontables/v2/query").
         with(:body => {"sql"=>"INSERT INTO 1 ('Product', 'Inventory') VALUES ('Hats', '1234')"},
              :headers => {'Authorization'=>'Bearer 1234'}).
         to_return(:status => 200, :body =>
          %({
           "kind": "fusiontables#sqlresponse",
           "columns": [
            "rowid"
           ],
           "rows": [
            [
             "301"
            ]
           ]
          }), :headers => {})

      table = connector.lookup_path "tables/1", user
      table.insert({"Product"=> "Hats","Inventory"=>"1234"}, nil)
    end

    it "should update a row" do
      stub_request(:get,  "https://www.googleapis.com/fusiontables/v2/query?sql=SELECT%20ROWID%20FROM%201%20WHERE%20'Product'='Black%20Shoes'").
       with(:headers => {'Authorization'=>'Bearer 1234'}).
       to_return(:status => 200, :body =>
        %({
           "kind": "fusiontables#sqlresponse",
           "columns": [
            "rowid"
           ],
          "rows": [
            [
             "201"
            ]
          ]
          }), :headers => {})

      stub_request(:post, "https://www.googleapis.com/fusiontables/v2/query").
         with(:body => {"sql"=>"UPDATE 1 SET 'Inventory' = '12' WHERE ROWID = '201'"},
              :headers => {'Authorization'=>'Bearer 1234'}).
         to_return(:status => 200, :body =>
          %({
            "kind": "fusiontables#sqlresponse",
            "columns": [
              "affected_rows"
            ],
              "rows": [
            [
             "1"
            ]
            ]
          }), :headers => {})

      table = connector.lookup_path "tables/1", user
      res = table.update({"Product"=>"Black Shoes"}, {"Inventory"=>"12"}, nil)
      expect(res).to eq(1)
    end

    it "should not update anything if no records match the search" do
      stub_request(:get,  "https://www.googleapis.com/fusiontables/v2/query?sql=SELECT%20ROWID%20FROM%201%20WHERE%20'Product'='Black%20Shoes'").
       with(:headers => {'Authorization'=>'Bearer 1234'}).
       to_return(:status => 200, :body =>
        %({
           "kind": "fusiontables#sqlresponse",
           "columns": [
            "rowid"
           ],
          "rows": [
            [
            ]
          ]
          }), :headers => {})

      table = connector.lookup_path "tables/1", user
      res = table.update({"Product"=>"Black Shoes"}, {"Inventory"=>"12"}, nil)
      expect(res).to eq(0)
    end

    it "should update multiple rows" do
      stub_request(:get,  "https://www.googleapis.com/fusiontables/v2/query?sql=SELECT%20ROWID%20FROM%201%20WHERE%20'Product'='Black%20Shoes'").
       with(:headers => {'Authorization'=>'Bearer 1234'}).
       to_return(:status => 200, :body =>
        %({
           "kind": "fusiontables#sqlresponse",
           "columns": [
            "rowid"
           ],
          "rows": [
            [
              "201"
            ],
            [
              "202"
            ]
          ]
          }), :headers => {})

      stub_request(:post, "https://www.googleapis.com/fusiontables/v2/query").
        with(:body => {"sql"=>"UPDATE 1 SET 'Inventory' = '12' WHERE ROWID = '201'"},
              :headers => {'Authorization'=>'Bearer 1234'}).
        to_return(:status => 200, :body =>
          %({
            "kind": "fusiontables#sqlresponse",
            "columns": [
              "affected_rows"
            ],
              "rows": [
            [
             "1"
            ]
            ]
          }), :headers => {})

      stub_request(:post, "https://www.googleapis.com/fusiontables/v2/query").
        with(:body => {"sql"=>"UPDATE 1 SET 'Inventory' = '12' WHERE ROWID = '202'"},
              :headers => {'Authorization'=>'Bearer 1234'}).
         to_return(:status => 200, :body =>
          %({
            "kind": "fusiontables#sqlresponse",
            "columns": [
              "affected_rows"
            ],
              "rows": [
            [
             "1"
            ]
            ]
          }), :headers => {})

      table = connector.lookup_path "tables/1", user
      res = table.update({"Product"=>"Black Shoes"}, {"Inventory"=>"12"}, nil)
      expect(res).to eq(2)
    end

    it "should delete one row" do
      stub_request(:get,  "https://www.googleapis.com/fusiontables/v2/query?sql=SELECT%20ROWID%20FROM%201%20WHERE%20'Product'='Black%20Shoes'").
       with(:headers => {'Authorization'=>'Bearer 1234'}).
       to_return(:status => 200, :body =>
        %({
           "kind": "fusiontables#sqlresponse",
           "columns": [
            "rowid"
           ],
          "rows": [
            [
             "201"
            ]
          ]
          }), :headers => {})

      stub_request(:post, "https://www.googleapis.com/fusiontables/v2/query").
         with(:body => {"sql"=>"DELETE FROM 1 WHERE ROWID = '201';"},
              :headers => {'Authorization'=>'Bearer 1234'}).
         to_return(:status => 200, :body =>
          %({
            "kind": "fusiontables#sqlresponse",
            "columns": [
              "affected_rows"
            ],
              "rows": [
            [
             "1"
            ]
            ]
          }), :headers => {})


      table = connector.lookup_path "tables/1", user
      res = table.delete({"Product"=>"Black Shoes"}, nil)
      expect(res).to eq(["201"])
    end

    it "should delete multiple rows" do
      stub_request(:get,  "https://www.googleapis.com/fusiontables/v2/query?sql=SELECT%20ROWID%20FROM%201%20WHERE%20'Product'='Black%20Shoes'").
       with(:headers => {'Authorization'=>'Bearer 1234'}).
       to_return(:status => 200, :body =>
        %({
           "kind": "fusiontables#sqlresponse",
           "columns": [
            "rowid"
           ],
          "rows": [
            [
              "201"
            ],
            [
              "202"
            ]
          ]
          }), :headers => {})

      stub_request(:post, "https://www.googleapis.com/fusiontables/v2/query").
         with(:body => {"sql"=>"DELETE FROM 1 WHERE ROWID = '201';"},
              :headers => {'Authorization'=>'Bearer 1234'}).
         to_return(:status => 200, :body =>
          %({
            "kind": "fusiontables#sqlresponse",
            "columns": [
              "affected_rows"
            ],
              "rows": [
            [
             "1"
            ]
            ]
          }), :headers => {})

      stub_request(:post, "https://www.googleapis.com/fusiontables/v2/query").
         with(:body => {"sql"=>"DELETE FROM 1 WHERE ROWID = '202';"},
              :headers => {'Authorization'=>'Bearer 1234'}).
         to_return(:status => 200, :body =>
          %({
            "kind": "fusiontables#sqlresponse",
            "columns": [
              "affected_rows"
            ],
              "rows": [
            [
             "1"
            ]
            ]
          }), :headers => {})


      table = connector.lookup_path "tables/1", user
      res = table.delete({"Product"=>"Black Shoes"}, nil)
      expect(res).to eq(["201", "202"])
    end

    it "should delete all rows in the table" do
      stub_request(:post, "https://www.googleapis.com/fusiontables/v2/query").
         with(:body => {"sql"=>"DELETE FROM 1"},
              :headers => {'Authorization'=>'Bearer 1234'}).
         to_return(:status => 200, :body =>
          %({
            "kind": "fusiontables#sqlresponse",
            "columns": [
              "affected_rows"
            ],
              "rows": [
            [
             "3"
            ]
            ]
          }), :headers => {})

      table = connector.lookup_path "tables/1", user
      table.delete({}, nil)
    end

  end

end
