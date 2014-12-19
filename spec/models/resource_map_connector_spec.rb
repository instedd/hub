describe ResourceMapConnector do
  let(:user) { User.make }

  describe "initialization" do
    it "should set defaults for new connector" do
      connector = ResourceMapConnector.make
      expect(connector.url).to eq("https://resourcemap.instedd.org")
      expect(connector.shared?).to eq(false)
    end
  end

  context "basic auth" do
    let(:connector) { ResourceMapConnector.new name: "bar", username: 'jdoe', password: '1234', user: user }

    it "finds root" do
      expect(connector.lookup [], user).to be(connector)
    end

    it "reflects on root" do
      expect(connector.reflect(context)).to eq({
        label: "bar",
        path: "",
        reflect_url: "http://server/api/reflect/connectors/1",
        type: :entity,
        properties: {
          "collections" => {
            label: "Collections",
            type: :entity_set,
            path: "collections",
            reflect_url: "http://server/api/reflect/connectors/1/collections"
          }
        }
      })
    end

    it "lists collections" do
      stub_request(:get, "https://jdoe:1234@resourcemap.instedd.org/api/collections.json").
        to_return(status: 200, body: %([
          {
            "id": 495,
            "name": "my collection"
          }]))

      collections = connector.lookup(%w(collections), context)

      expect(collections.reflect(context)).to eq({
        label: "Collections",
        path: "collections",
        reflect_url: "http://server/api/reflect/connectors/1/collections",
        type: :entity_set,
        protocol: [:query],
        entities: [
          {
            label: "my collection",
            path: "collections/495",
            type: :entity,
            reflect_url: "http://server/api/reflect/connectors/1/collections/495"
          }
        ]
      })
    end

    it "reflects on collection" do
      stub_request(:get, "https://jdoe:1234@resourcemap.instedd.org/api/collections.json").
        to_return(:status => 200, :body => %([{
            "id": 495,
            "name": "my collection"
        }]))

      collection = connector.lookup %w(collections 495), context

      expect(collection.reflect(context)).to eq({
        label: "my collection",
        path: "collections/495",
        reflect_url: "http://server/api/reflect/connectors/1/collections/495",
        type: :entity,
        properties: {
          "id" => {
            label: "Id",
            type: :integer
          },
          "name" => {
            label: "Name",
            type: :string
          },
          "sites" => {
            label: "Sites",
            type: :entity_set,
            path: "collections/495/sites",
            reflect_url: "http://server/api/reflect/connectors/1/collections/495/sites",
          },
        },
      })
    end

    it "reflects on sites" do
      stub_request(:get, "https://jdoe:1234@resourcemap.instedd.org/api/collections.json").
        to_return(:status => 200, :body => %([{
            "id": 495,
            "name": "my collection"
        }]))

      stub_request(:get, "https://jdoe:1234@resourcemap.instedd.org/api/collections/495/layers.json").
        to_return(:status => 200, :body => %([
          {
            "id": 123,
            "name": "my layer",
            "fields": [
              {
                "id": 234,
                "code": "field_code",
                "name": "my field",
                "kind": "text"
              }
            ]
          }]))

      sites = connector.lookup %w(collections 495 sites), context

      expect(sites.reflect(context)).to eq({
        label: "Sites",
        path: "collections/495/sites",
        protocol: [:query, :insert, :update, :delete],
        reflect_url: "http://server/api/reflect/connectors/1/collections/495/sites",
        type: :entity_set,
        entity_definition: {
          properties: {
            id: {
              label: "ID",
              type: :integer,
            },
            name: {
              label: "Name",
              type: :string,
            },
            lat: {
              label: "Latitude",
              type: :float,
            },
            long: {
              label: "Longitude",
              type: :float,
            },
            layers: {
              label: "Layers",
              type: {
                kind: :struct,
                members: {
                  "123" => {
                    label: "my layer",
                    type: {
                      kind: :struct,
                      members: {
                        "field_code" => {
                          label: "my field",
                          kind: :string,
                        },
                      },
                    },
                  },
                }
              }
            }
          }
        },
        actions: {
          "insert"=>{:label=>"Insert", :path=>"collections/495/sites/$actions/insert", :reflect_url=>"http://server/api/reflect/connectors/1/collections/495/sites/$actions/insert"},
          "update"=>{:label=>"Update", :path=>"collections/495/sites/$actions/update", :reflect_url=>"http://server/api/reflect/connectors/1/collections/495/sites/$actions/update"},
          "delete"=>{:label=>"Delete", :path=>"collections/495/sites/$actions/delete", :reflect_url=>"http://server/api/reflect/connectors/1/collections/495/sites/$actions/delete"}
        }
      })
    end

    it "executes insert site action" do
      stub_request(:get, "https://jdoe:1234@resourcemap.instedd.org/api/collections.json").
        to_return(:status => 200, :body => %([{
            "id": 495,
            "name": "my collection"
        }]))

      stub_request(:get, "https://jdoe:1234@resourcemap.instedd.org/api/collections/495/layers.json").
        to_return(:status => 200, :body => %([
          {
            "id": 123,
            "name": "my layer",
            "fields": [
              {
                "id": 234,
                "code": "field_code",
                "name": "my field",
                "kind": "text"
              }
            ]
          }]))

      stub_request(:post, "https://jdoe:1234@resourcemap.instedd.org/api/collections/495/sites.json").
         with(:body => {"site"=> %({"name":"New site","lat":12.34,"lng":56.78,"properties":{"field_code":"New value"}})},
              :headers => {'Content-Type'=>'application/x-www-form-urlencoded'}).
         to_return(:status => 200, :body => "")

      sites = connector.lookup %w(collections 495 sites), context
      sites.insert({
        "name" => "New site",
        "lat" => 12.34,
        "long" => 56.78,
        "layers" => {
          "123" => {
            "field_code" => "New value",
          },
        }
      }, context)

      expect(a_request(:post, "https://jdoe:1234@resourcemap.instedd.org/api/collections/495/sites.json").
         with(:body => {"site"=> %({"name":"New site","lat":12.34,"lng":56.78,"properties":{"field_code":"New value"}})},
              :headers => {'Content-Type'=>'application/x-www-form-urlencoded'})
         ).to have_been_made
    end

    it "executes query site action" do
      stub_request(:get, "https://jdoe:1234@resourcemap.instedd.org/api/collections.json").
        to_return(:status => 200, :body => %([{
            "id": 495,
            "name": "my collection"
        }]))

      stub_request(:get, "https://jdoe:1234@resourcemap.instedd.org/api/collections/495/layers.json").
        to_return(:status => 200, :body => %([
          {
            "id": 123,
            "name": "my layer",
            "fields": [
              {
                "id": 234,
                "code": "field_code",
                "name": "my field",
                "kind": "text"
              }
            ]
          }]))

      stub_request(:get, "https://jdoe:1234@resourcemap.instedd.org/api/collections/495.json?name=#{CGI.escape "New site"}&lat=12.34&lng=56.78&field_code=#{CGI.escape "Some value"}").
         to_return(:status => 200, :body => %(
            {
              "name": "Hub collection",
              "count": 1,
              "totalPages": null,
              "sites": [
                {
                  "id": 1234,
                  "name": "My new site",
                  "createdAt": "2014-12-18T20:59:40.695Z",
                  "updatedAt": "2014-12-18T20:59:40.695Z",
                  "lat": 12.5,
                  "long": 13.5,
                  "properties": {
                    "field_code": "some value"
                  }
                }
              ]
            }
          ))

      sites = connector.lookup %w(collections 495 sites), context
      results = sites.query({
        "name" => "New site",
        "lat" => 12.34,
        "long" => 56.78,
        "layers" => {
          "123" => {
            "field_code" => "Some value",
          },
        }
      }, context, {})

      expect(results).to eq([{
        "id" => 1234,
        "name" => "My new site",
        "lat" => 12.5,
        "long" => 13.5,
        "layers" => {
          "123" => {
            "field_code" => "some value",
          }
        }
      }])
    end

    it "executes update site action" do
      stub_request(:get, "https://jdoe:1234@resourcemap.instedd.org/api/collections.json").
        to_return(:status => 200, :body => %([{
            "id": 495,
            "name": "my collection"
        }]))

      stub_request(:get, "https://jdoe:1234@resourcemap.instedd.org/api/collections/495/layers.json").
        to_return(:status => 200, :body => %([
          {
            "id": 123,
            "name": "my layer",
            "fields": [
              {
                "id": 234,
                "code": "field_code",
                "name": "my field",
                "kind": "text"
              }
            ]
          }]))

      stub_request(:get, "https://jdoe:1234@resourcemap.instedd.org/api/collections/495.json?field_code=#{CGI.escape "Some value"}").
         to_return(:status => 200, :body => %(
            {
              "name": "Hub collection",
              "count": 1,
              "totalPages": null,
              "sites": [
                {
                  "id": 1234,
                  "name": "My new site",
                  "createdAt": "2014-12-18T20:59:40.695Z",
                  "updatedAt": "2014-12-18T20:59:40.695Z",
                  "lat": 12.5,
                  "long": 13.5,
                  "properties": {
                    "field_code": "some value"
                  }
                }
              ]
            }
          ))

      stub_request(:post, "https://jdoe:1234@resourcemap.instedd.org/api/sites/1234/partial_update.json").
         with(:body => {"site"=> %({"properties":{"field_code":"Some other value"}})},
              :headers => {'Content-Type'=>'application/x-www-form-urlencoded'}).
         to_return(:status => 200, :body => "")

      sites = connector.lookup %w(collections 495 sites), context
      results = sites.update(
        {
          "layers" => {
            "123" => {
              "field_code" => "Some value",
            },
          }
        },
        {
          "layers" => {
            "123" => {
              "field_code" => "Some other value",
            },
          }
        },
        context)

      expect(a_request(:post, "https://jdoe:1234@resourcemap.instedd.org/api/sites/1234/partial_update.json").
         with(:body => {"site"=> %({"properties":{"field_code":"Some other value"}})},
              :headers => {'Content-Type'=>'application/x-www-form-urlencoded'})
         ).to have_been_made
    end

    it "executes delete site action" do
      stub_request(:get, "https://jdoe:1234@resourcemap.instedd.org/api/collections.json").
        to_return(:status => 200, :body => %([{
            "id": 495,
            "name": "my collection"
        }]))

      stub_request(:get, "https://jdoe:1234@resourcemap.instedd.org/api/collections/495/layers.json").
        to_return(:status => 200, :body => %([
          {
            "id": 123,
            "name": "my layer",
            "fields": [
              {
                "id": 234,
                "code": "field_code",
                "name": "my field",
                "kind": "text"
              }
            ]
          }]))

      stub_request(:get, "https://jdoe:1234@resourcemap.instedd.org/api/collections/495.json?field_code=#{CGI.escape "Some value"}").
         to_return(:status => 200, :body => %(
            {
              "name": "Hub collection",
              "count": 1,
              "totalPages": null,
              "sites": [
                {
                  "id": 1234,
                  "name": "My new site",
                  "createdAt": "2014-12-18T20:59:40.695Z",
                  "updatedAt": "2014-12-18T20:59:40.695Z",
                  "lat": 12.5,
                  "long": 13.5,
                  "properties": {
                    "field_code": "some value"
                  }
                }
              ]
            }
          ))

      stub_request(:delete, "https://jdoe:1234@resourcemap.instedd.org/api/sites/1234.json").
         to_return(:status => 200, :body => "")

      sites = connector.lookup %w(collections 495 sites), context
      results = sites.delete(
        {
          "layers" => {
            "123" => {
              "field_code" => "Some value",
            },
          }
        },
        context)

      expect(a_request(:delete, "https://jdoe:1234@resourcemap.instedd.org/api/sites/1234.json")
         ).to have_been_made
    end
  end
end
