describe VerboiceConnector do
  let(:user) { User.make }
  let(:url_proc) { ->(path) { "http://server/#{path}" }}
  describe "initialization" do
    it "should set defaults for new connector" do
      connector = VerboiceConnector.make
      expect(connector.url).to eq("https://verboice.instedd.org")
      expect(connector.shared?).to eq(false)
    end
  end

  context "basic auth" do
    let(:connector) { VerboiceConnector.new name: "bar", username: 'jdoe', password: '1234', user: user }

    describe "lookup" do

      it "finds root" do
        expect(connector.lookup [], user).to be(connector)
      end

      it "reflects on root" do
        expect(connector.reflect(url_proc, user)).to eq({
          label: "bar",
          path: "",
          reflect_url: "http://server/",
          type: :entity,
          properties: {
            "projects" => {
              label: "Projects",
              type: :entity_set,
              path: "projects",
              reflect_url: "http://server/projects"
            }
          }
        })
      end

      it "lists projects" do
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects.json").
          to_return(status: 200, body: %([
            {
              "id": 495,
              "name": "my project",
              "call_flows": [{
                "id": 740,
                "name": "my flow"}],
              "schedules": []
            }]), headers: {})

        projects = connector.lookup(%w(projects), user)

        expect(projects.reflect(url_proc, user)).to eq({
          label: "Projects",
          path: "projects",
          reflect_url: "http://server/projects",
          type: :entity_set,
          protocol: [:query],
          actions: {
            "query" => {
              label: "Query",
              path: "projects/$actions/query",
              reflect_url: "http://server/projects/$actions/query"
            }
          },
          entities: [
            {
              label: "my project",
              path: "projects/495",
              type: :entity,
              reflect_url: "http://server/projects/495"
            }
          ]
        })
      end

      it "reflects on project" do
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495.json").
          to_return(:status => 200, :body => %({
            "id": 495,
            "name": "my project",
            "call_flows": [],
            "addresses": [],
            "schedules": []
          }), :headers => {})

        projects = connector.lookup %w(projects 495), user

        expect(projects.reflect(url_proc, user)).to eq({
          label: "my project",
          path: "projects/495",
          reflect_url: "http://server/projects/495",
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
            "call_flows" => {
              label: "Call flows",
              type: :entity_set,
              path: "projects/495/call_flows",
              reflect_url: "http://server/projects/495/call_flows",
            },
            "phone_book" => {
              label: "Phone Book",
              type: :entity_set,
              path: "projects/495/phone_book",
              reflect_url: "http://server/projects/495/phone_book",
            }
          },
          actions: {
            "call"=> {
              label: "Call",
              path: "projects/495/$actions/call",
              reflect_url: "http://server/projects/495/$actions/call",
            }
          }
        })
      end

      it "reflects on project call flows" do
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495.json").
         to_return(:status => 200, :body => %({
            "id": 495,
            "name": "my project",
            "call_flows": [{
              "id": 740,
              "name": "my flow"}],
            "addresses": [],
            "schedules": []
          }), :headers => {})

        call_flows = connector.lookup %w(projects 495 call_flows), user

        expect(call_flows.reflect(url_proc, user)).to eq({
          label: "Call flows",
          path: "projects/495/call_flows",
          reflect_url: "http://server/projects/495/call_flows",
          type: :entity_set,
          protocol: [:query],
          actions: {
            "query" => {
              label: "Query",
              path: "projects/495/call_flows/$actions/query",
              reflect_url: "http://server/projects/495/call_flows/$actions/query"
            }
          },
          entities: [{
            label: "my flow",
            path: "projects/495/call_flows/740",
            type: :entity,
            reflect_url: "http://server/projects/495/call_flows/740",
          }],
        })
      end

      it "reflects on call flow" do
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495.json").
          to_return(:status => 200, :body => %({
            "id": 495,
            "name": "my project",
            "call_flows": [],
            "addresses": [],
            "schedules": []
          }), :headers => {})
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495/call_flows/740.json").
          to_return(:status => 200, :body => %({
            "id": 740,
            "name": "my flow"
          }), :headers => {})

        call_flow = connector.lookup %w(projects 495 call_flows 740), user

        expect(call_flow.reflect(url_proc, user)).to eq({
          label: "my flow",
          path: "projects/495/call_flows/740",
          reflect_url: "http://server/projects/495/call_flows/740",
          type: :entity,
          properties: {
            id: { label: "Id", type: :integer },
            name: { label: "Name", type: :string}
          },
          events: {
            "call_finished" => {
              label: "Call finished",
              path: "projects/495/call_flows/740/$events/call_finished",
              reflect_url: "http://server/projects/495/call_flows/740/$events/call_finished"
            }
          }
        })
      end

      it "reflects on call flow call finished event" do
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495.json").
          to_return(:status => 200, :body => %({"id": 495,"contact_vars":["name","age"]}), :headers => {})
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495/call_flows/740.json").
          to_return(:status => 200, :body => %({
            "id": 740,
            "name": "my flow"
          }), :headers => {})

        event = connector.lookup %w(projects 495 call_flows 740 $events call_finished), user

        expect(event.reflect(url_proc, user)).to eq({
          label: "Call finished",
          args: {
            "name" => {type: :string},
            "age" => {type: :string},
            "address" => {type: :string},
          }
        })
      end

      it "reflects on call" do
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495.json").
          to_return(:status => 200, :body => %({
            "id": 495,
            "name": "my project",
            "call_flows": [],
            "addresses": [],
            "schedules": []
          }), :headers => {})

        projects = connector.lookup %w(projects 495 $actions call), user

        expect(projects.reflect(url_proc, user)).to eq({
          label:"Call",
          args: {
            channel: {
              type: "string",
              label: "Channel"},
            number: {
              type: "string",
              label:"Number"
            }
          }
        })
      end
    end

    describe "call" do
      it "invokes" do
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495.json").
          to_return(:status => 200, :body => %({
            "id": 495,
            "name": "my project",
            "call_flows": [],
            "addresses": [],
            "schedules": []
          }), :headers => {})
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/call?address=&channel=Channel").
         to_return(:status => 200, :body => %({"call_id":755961,"state":"queued"}), :headers => {})

        projects = connector.lookup %w(projects 495 $actions call), user

        response = projects.invoke({'channel' => 'Channel', 'address' => '123'}, user)
        expect(response).to eq({
          "call_id" => 755961,
          "state" => "queued"
        })
      end
    end

    describe "query" do
      it "should filter by address" do
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495.json").
          to_return(status: 200, body: %({
              "id": 495,
              "name": "my project"
            }), headers: {})

        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495/contacts/by_address/12345.json").
          to_return(:status => 200, :body => %(
                {
                  "id": 1,
                  "addresses": ["12345", "67890"],
                  "vars": []
                }
              ), :headers => {})

        phone_book = connector.lookup %w(projects 495 phone_book), user

        response = phone_book.query({address: "12345"}, user, {})
        response = response.map {|contact| contact.raw(url_proc, user) }
        expect(response).to eq([
          {
            id: 1,
            address: "12345"
          },
          {
            id: 1,
            address: "67890"
          }
        ])
      end
    end
  end

  context "guisso with shared connectors" do
    let(:connector) { VerboiceConnector.new name: "foo"}
    let(:user) { User.make }

    before(:each) do
      allow(Guisso).to receive_messages(
        enabled?: true,
        url: "http://guisso.com",
        client_id: "12345",
        client_secret: "12345"
      )

      stub_request(:post, "http://guisso.com/oauth2/token").
        with(:body => {"grant_type"=>"client_credentials", "scope"=>"app=verboice.instedd.org user=#{user.email}"}).
        to_return(:status => 200, :body => '{
          "token_type": "Bearer",
          "access_token": "This is a guisso auth token!",
          "expires_in": 7200
          }', :headers => {})
    end

    describe "lookup" do

      it "finds root" do
        expect(connector.lookup [], user).to be(connector)
      end

      it "reflects on root" do
        expect(connector.reflect(url_proc, user)).to eq({
          label: "foo",
          path: "",
          reflect_url: "http://server/",
          type: :entity,
          properties: {
            "projects" => {
              label: "Projects",
              type: :entity_set,
              path: "projects",
              reflect_url: "http://server/projects",
            }
          }
        })
      end

      it "lists projects" do
        stub_request(:get, "https://verboice.instedd.org/api/projects.json").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(status: 200, body: %([
            {
              "id": 495,
              "name": "my project",
              "call_flows": [],
              "addresses": [],
              "schedules": []
            }]), headers: {})

        projects = connector.lookup(%w(projects), user)

        expect(projects.reflect(url_proc, user)).to eq({
          label: "Projects",
          path: "projects",
          reflect_url: "http://server/projects",
          type: :entity_set,
          protocol: [:query],
          actions: {
            "query" => {
              label: "Query",
              path: "projects/$actions/query",
              reflect_url: "http://server/projects/$actions/query"
            }
          },
          entities: [
            {
              label: "my project",
              path: "projects/495",
              type: :entity,
              reflect_url: "http://server/projects/495"
            }
          ]
        })
      end

      it "reflects on project" do
        stub_request(:get, "https://verboice.instedd.org/api/projects/495.json").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(status: 200, body: %({
            "id": 495,
            "name": "my project",
            "call_flows": [],
            "addresses": [],
            "schedules": []
            }), headers: {})

        projects = connector.lookup %w(projects 495), user

        expect(projects.reflect(url_proc, user)).to eq({
          label: "my project",
          path: "projects/495",
          reflect_url: "http://server/projects/495",
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
            "call_flows" => {
              label: "Call flows",
              type: :entity_set,
              path: "projects/495/call_flows",
              reflect_url: "http://server/projects/495/call_flows",
            },
            "phone_book" => {
              label: "Phone Book",
              type: :entity_set,
              path: "projects/495/phone_book",
              reflect_url: "http://server/projects/495/phone_book",
            }
          },
          actions: {
            "call"=> {
              label: "Call",
              path: "projects/495/$actions/call",
              reflect_url: "http://server/projects/495/$actions/call"
            }
          }
        })
      end

      it "reflects on call" do
        stub_request(:get, "https://verboice.instedd.org/api/projects/495.json").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(status: 200, body: %({
              "id": 495,
              "name": "my project",
              "call_flows": [],
              "schedules": []
            }), headers: {})

        projects = connector.lookup %w(projects 495 $actions call), user

        expect(projects.reflect(url_proc, user)).to eq({
          label:"Call",
          args: {
            channel: {
              type: "string",
              label: "Channel"},
            number: {
              type: "string",
              label:"Number"
            }
          }
        })
      end
    end

    describe "call" do
      it "invokes" do
        stub_request(:get, "https://verboice.instedd.org/api/projects/495.json").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(status: 200, body: %({
              "id": 495,
              "name": "my project",
              "call_flows": [],
              "schedules": []
            }), headers: {})
        stub_request(:get, "https://verboice.instedd.org/api/call?address=123&channel=Channel").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(:status => 200, :body => %({"call_id":755961,"state":"queued"}), :headers => {})

        projects = connector.lookup %w(projects 495 $actions call), user

        response = projects.invoke({'channel' => 'Channel', 'number' => '123'}, user)
        expect(response).to eq({
          "call_id" => 755961,
          "state" => "queued"
        })
      end

      it "escapes url parameters" do
        stub_request(:get, "https://verboice.instedd.org/api/projects/495.json").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(status: 200, body: %({
              "id": 495,
              "name": "my project",
              "call_flows": [],
              "schedules": []
            }), headers: {})
        stub_request(:get, "https://verboice.instedd.org/api/call?address=123%20456&channel=Channel%20123").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(:status => 200, :body => %({"call_id":755961,"state":"queued"}), :headers => {})

        projects = connector.lookup %w(projects 495 $actions call), user

        response = projects.invoke({'channel' => 'Channel 123', 'number' => '123 456'}, user)
        expect(response).to be_present
      end
    end
  end

  describe "perform subscribed events" do
    let(:verboice_connector) { VerboiceConnector.make! username: 'jdoe', password: '1234', user: user }

    let(:event_handler_1) { EventHandler.create!(
      connector: verboice_connector,
      event: "projects/2/call_flows/2/$events/call_finished",
      target_connector: verboice_connector,
      action: "projects/2/call_flows/2/$events/call_finished",
    )}

    let(:event_handler_2) { EventHandler.create!(
      connector: verboice_connector,
      event: "projects/2/call_flows/2/$events/call_finished",
      target_connector: verboice_connector,
      action: "projects/2/call_flows/2/$events/call_finished",
    )}
    before(:each) do
      stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/2.json").
        to_return(status: 200, body: %({
            "id": 2,
            "name": "my project",
            "call_flows": [{
              "id": 740,
              "name": "my flow"
            }],
            "schedules": []
          }), headers: {})
      stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/2/call_flows/2.json").
        to_return(status: 200, body: %({
            "id": 740,
            "name": "my flow"
          }), headers: {})
      event_handler_1
      event_handler_2
    end

    it "should invoke event handlers when processing a queued job" do
      data = {"project_id"=>2, "call_flow_id"=>2, "address"=>"17772632588", "vars"=>{"age"=>"20"}}.to_json
      trigger_count = 0
      allow_any_instance_of(EventHandler).to receive(:trigger) do |data|
        trigger_count+=1
      end

      VerboiceConnector::CallTask.perform(verboice_connector.id, data)

      expect(trigger_count).to eq(2)
    end
  end

  it "generates secret token on demand" do
    connector = VerboiceConnector.make
    token = connector.generate_secret_token!
    expect(connector).to be_persisted

    expect(connector.authenticate_with_secret_token(token)).to be_truthy
    expect(connector.authenticate_with_secret_token("#{token}x")).to be_falsey
  end
end
