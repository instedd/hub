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

    describe "lookup" do
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
              "123" => {
                label: "my layer",
                type: {
                  kind: :struct,
                  members: {
                    "234" => {
                      label: "my field",
                      kind: :string,
                    },
                  },
                },
              },
            }
          },
          actions: {
            "insert"=>{:label=>"Insert", :path=>"collections/495/sites/$actions/insert", :reflect_url=>"http://server/api/reflect/connectors/1/collections/495/sites/$actions/insert"},
            "update"=>{:label=>"Update", :path=>"collections/495/sites/$actions/update", :reflect_url=>"http://server/api/reflect/connectors/1/collections/495/sites/$actions/update"},
            "delete"=>{:label=>"Delete", :path=>"collections/495/sites/$actions/delete", :reflect_url=>"http://server/api/reflect/connectors/1/collections/495/sites/$actions/delete"}
          }
        })
      end
    end
  end
end
