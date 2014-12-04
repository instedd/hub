describe MBuilderConnector do
  let(:user) { User.make }

  context "basic auth" do
    let(:connector) { MBuilderConnector.new url: "http://example.com", username: 'jdoe', password: '1234', user: user }

    describe "lookup" do
      it "finds root" do
        expect(connector.lookup [], context).to be(connector)
      end

      it "reflects on root" do
        expect(connector.reflect(context)).to eq({
          label: nil,
          path: "",
          reflect_url: "http://server/api/reflect/connectors/1",
          type: :entity,
          properties: {
            "applications" => {
              label: "Applications",
              type: :entity_set,
              path: "applications",
              reflect_url: "http://server/api/reflect/connectors/1/applications"
            }
          }
        })
      end

      it "lists applications" do
        stub_request(:get, "http://jdoe:1234@example.com/api/applications").
          to_return(status: 200, body: %([{"id": 1, "name": "Application 1"}]), headers: {})

        applications = connector.lookup %w(applications), context
        expect(applications.reflect(context)).to eq({
          label: "Applications",
          path: "applications",
          reflect_url: "http://server/api/reflect/connectors/1/applications",
          type: :entity_set,
          protocol: [:query],
          entities: [
            {
              label: "Application 1",
              path: "applications/1",
              type: :entity,
              reflect_url: "http://server/api/reflect/connectors/1/applications/1"
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

        application = connector.lookup %w(applications 1), context

        expect(application.reflect(context)).to eq({
          label: nil,
          path: "applications/1",
          reflect_url: "http://server/api/reflect/connectors/1/applications/1",
          type: :entity,
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
              reflect_url: "http://server/api/reflect/connectors/1/applications/1/$actions/trigger_2"
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

        application = connector.lookup %w(applications 1 $actions trigger_2), context
        expect(application.reflect(context)).to eq({
          label: "Trigger asd",
          args: {
            "foo" => {
              "label" => "Foo",
              "type" => "string"
            }
          }
        })
      end
    end

    describe "trigger" do
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

        application = connector.lookup %w(applications 1 $actions trigger_2), context

        stub_request(:post, "http://jdoe:1234@example.com/external/application/1/trigger/asd?foo=bar").
          to_return(status: 200, body: "ok foo!", headers: {})

        expect(application.invoke({'foo' => 'bar'}, context)).to eq("ok foo!")
      end
    end
  end

  context "guisso" do
    let(:connector) { MBuilderConnector.new url: "http://example.com", username: 'jdoe', password: '1234' }
    before(:each) do
      allow(Guisso).to receive_messages(
        enabled?: true,
        url: "http://guisso.com",
        client_id: "12345",
        client_secret: "12345"
      )

      stub_request(:post, "http://guisso.com/oauth2/token").
        with(:body => {"grant_type"=>"client_credentials", "scope"=>"app=example.com user=#{user.email}"}).
        to_return(:status => 200, :body => '{
          "token_type": "Bearer",
          "access_token": "This is a guisso auth token!",
          "expires_in": 7200
          }', :headers => {})
    end

    describe "lookup" do

      it "finds root" do
        expect(connector.lookup [], context).to be(connector)
      end

      it "reflects on root" do
        expect(connector.reflect(context)).to eq({
          label: nil,
          path: "",
          reflect_url: "http://server/api/reflect/connectors/1",
          type: :entity,
          properties: {
            "applications" => {
              label: "Applications",
              type: :entity_set,
              path: "applications",
              reflect_url: "http://server/api/reflect/connectors/1/applications"
            }
          }
        })
      end

      it "lists applications" do
        stub_request(:get, "http://example.com/api/applications").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(status: 200, body: %([{"id": 1, "name": "Application 1"}]), headers: {})

        applications = connector.lookup %w(applications), context
        expect(applications.reflect(context)).to eq({
          label: "Applications",
          path: "applications",
          reflect_url: "http://server/api/reflect/connectors/1/applications",
          type: :entity_set,
          protocol: [:query],
          entities: [
            {
              label: "Application 1",
              path: "applications/1",
              type: :entity,
              reflect_url: "http://server/api/reflect/connectors/1/applications/1"
            }
          ]
        })
      end

        it "reflects on application" do
        stub_request(:get, "http://example.com/api/applications/1/actions").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
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

        application = connector.lookup %w(applications 1), context

        expect(application.reflect(context)).to eq({
          label: nil,
          path: "applications/1",
          reflect_url: "http://server/api/reflect/connectors/1/applications/1",
          type: :entity,
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
              reflect_url: "http://server/api/reflect/connectors/1/applications/1/$actions/trigger_2"
            }
          }
        })
      end

      it "reflects on trigger" do
        stub_request(:get, "http://example.com/api/applications/1/actions").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
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

        application = connector.lookup %w(applications 1 $actions trigger_2), context
        expect(application.reflect(context)).to eq({
          label: "Trigger asd",
          args: {
            "foo" => {
              "label" => "Foo",
              "type" => "string"
            }
          }
        })
      end
    end

    describe "trigger" do
      it "invokes" do
        stub_request(:get, "http://example.com/api/applications/1/actions").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
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

        application = connector.lookup %w(applications 1 $actions trigger_2), context

        stub_request(:post, "http://example.com/external/application/1/trigger/asd?foo=bar").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(status: 200, body: "ok foo!", headers: {})

        expect(application.invoke({'foo' => 'bar'}, context)).to eq("ok foo!")
      end
    end
  end
end
