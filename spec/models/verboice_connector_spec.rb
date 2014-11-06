describe VerboiceConnector do
  describe "initialization" do
    it "should set defaults for new connector" do
      connector = VerboiceConnector.make
      expect(connector.url).to eq("https://verboice.instedd.org")
      expect(connector.shared).to eq(false)
    end
  end

  describe "lookup" do
    let(:connector) { VerboiceConnector.new username: 'jdoe', password: '1234', shared: false }
    let(:url_proc) { ->(path) { "http://server/#{path}" }}
    let(:user) { User.make }

    it "finds root" do
      expect(connector.lookup []).to be(connector)
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
        with(:headers => {'Accept'=>'*/*; q=0.5, application/xml', 'Accept-Encoding'=>'gzip, deflate', 'User-Agent'=>'Ruby'}).
        to_return(status: 200, body: %([
          {
            "id": 495,
            "name": "my project",
            "call_flows": [{
              "id": 740,
              "name": "my flow"}],
            "schedules": []
          }]), headers: {})

      applications = connector.lookup %w(projects)
      expect(applications.reflect(url_proc, user)).to eq({
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
      application = connector.lookup %w(projects 495)
      expect(application.reflect(url_proc, user)).to eq({
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
      application = connector.lookup %w(projects 495 $actions call)
      expect(application.reflect(url_proc)).to eq({
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

end
