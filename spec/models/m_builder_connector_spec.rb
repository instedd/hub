describe MBuilderConnector do
  describe "lookup" do
    let(:connector) { MBuilderConnector.new url: "http://example.com", username: 'jdoe', password: '1234' }
    let(:url_proc) { ->(path) { "http://server/#{path}" }}
    let(:user) { User.make }

    it "finds root" do
      expect(connector.lookup []).to be(connector)
    end

    it "reflects on root" do
      expect(connector.reflect(url_proc, user)).to eq({
        properties: {
          "applications" => {
            label: "Applications",
            type: :entity_set,
            path: "applications",
            reflect_url: "http://server/applications"
          }
        }
      })
    end

    it "lists applications" do
      stub_request(:get, "http://jdoe:1234@example.com/api/applications").
        to_return(status: 200, body: %([{"id": 1, "name": "Application 1"}]), headers: {})

      applications = connector.lookup %w(applications)
      expect(applications.reflect(url_proc, user)).to eq({
        entities: [
          {
            label: "Application 1",
            path: "applications/1",
            reflect_url: "http://server/applications/1"
          }
        ]
      })
    end

    it "reflects on application" do
      stub_request(:get, "http://jdoe:1234@example.com/api/applications/1/actions").
        to_return(status: 200, body: %([
          {
            "id": 2,
            "action": "asd",
            "method": "POST",
            "url": "http://example.com/external/application/1/trigger/asd",
            "parameters" : {
              "foo" : {"label" : "Foo", "type" : "string"}
            }
          }]), headers: {})

      application = connector.lookup %w(applications 1)
      expect(application.reflect(url_proc, user)).to eq({
        properties: {
          "id" => {
            label: "Id",
            type: :integer
          },
          "name" => {
            :label => "Name",
            :type => :string
          }
        },
        actions: {
          "trigger_2" => {
            label: "Trigger asd",
            path: "applications/1/$actions/trigger_2",
            reflect_url: "http://server/applications/1/$actions/trigger_2"
          }
        }
      })
    end

    it "reflects on trigger" do
      stub_request(:get, "http://jdoe:1234@example.com/api/applications/1/actions").
        to_return(status: 200, body: %([
          {
            "id": 2,
            "action": "asd",
            "method": "POST",
            "url": "http://example.com/external/application/1/trigger/asd",
            "parameters" : {
              "foo" : {"label" : "Foo", "type" : "string"}
            }
          }]), headers: {})

      application = connector.lookup %w(applications 1 $actions trigger_2)
      expect(application.reflect(url_proc)).to eq({
        label: "Trigger asd",
        args: {
          "foo" => {
            "label" => "Foo",
            "type" => "string"
          }
        }
      })
    end

    it "invokes" do
      stub_request(:get, "http://jdoe:1234@example.com/api/applications/1/actions").
        to_return(status: 200, body: %([
          {
            "id": 2,
            "action": "asd",
            "method": "POST",
            "url": "http://example.com/external/application/1/trigger/asd",
            "parameters" : {
              "foo" : {"label" : "Foo", "type" : "string"}
            }
          }]), headers: {})

      application = connector.lookup %w(applications 1 $actions trigger_2)

      stub_request(:post, "http://jdoe:1234@example.com/external/application/1/trigger/asd?foo=bar").
        to_return(status: 200, body: "ok foo!", headers: {})

      expect(application.invoke({'foo' => 'bar'})).to eq("ok foo!")
    end
  end
end
