describe VerboiceConnector do
  describe "initialization" do
    it "should set defaults for new connector" do
      connector = VerboiceConnector.make
      expect(connector.url).to eq("https://verboice.instedd.org")
      expect(connector.shared).to eq(false)
    end
  end

  context "basic auth" do
    let(:connector) { VerboiceConnector.new username: 'jdoe', password: '1234', shared: false }
    let(:user) { User.make }

    describe "lookup" do
      let(:url_proc) { ->(path) { "http://server/#{path}" }}

      it "finds root" do
        expect(connector.lookup [], user).to be(connector)
      end

      it "reflects on root" do
        expect(connector.reflect(url_proc, user)).to eq({
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
          entities: [
            {
              label: "my project",
              path: "projects/495",
              reflect_url: "http://server/projects/495"
            }
          ]
        })
      end

      it "reflects on project" do
        projects = connector.lookup %w(projects 495), user
        expect(projects.reflect(url_proc, user)).to eq({
          properties: {
            "id" => {
              label: "Id",
              type: :integer
            },
            "name" => {
              label: "Name",
              type: :string
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
        projects = connector.lookup %w(projects 495 $actions call), user
        expect(projects.reflect(url_proc)).to eq({
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
  end

  context "guisso with shared connectors" do
    let(:connector) { VerboiceConnector.new shared: true }
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
      let(:url_proc) { ->(path) { "http://server/#{path}" }}

      it "finds root" do
        expect(connector.lookup [], user).to be(connector)
      end

      it "reflects on root" do
        expect(connector.reflect(url_proc, user)).to eq({
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
        stub_request(:get, "https://verboice.instedd.org/api/projects.json").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
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
          entities: [
            {
              label: "my project",
              path: "projects/495",
              reflect_url: "http://server/projects/495"
            }
          ]
        })
      end

      it "reflects on project" do
        projects = connector.lookup %w(projects 495), user
        expect(projects.reflect(url_proc, user)).to eq({
          properties: {
            "id" => {
              label: "Id",
              type: :integer
            },
            "name" => {
              label: "Name",
              type: :string
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
        projects = connector.lookup %w(projects 495 $actions call), user
        expect(projects.reflect(url_proc)).to eq({
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
        stub_request(:get, "https://verboice.instedd.org/api/call?address=&channel=Channel").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(:status => 200, :body => %({"call_id":755961,"state":"queued"}), :headers => {})

        projects = connector.lookup %w(projects 495 $actions call), user

        response = projects.invoke({'channel' => 'Channel', 'address' => '123'}, user)
        expect(response).to eq({
          "call_id" => 755961,
          "state" => "queued"
        })
      end
    end
  end


end
