describe VerboiceConnector do
  let(:user) { User.make }
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
        expect(connector.reflect(context)).to eq({
          label: "bar",
          path: "",
          reflect_url: "http://server/api/reflect/connectors/1",
          type: :entity,
          properties: {
            "projects" => {
              label: "Projects",
              type: :entity_set,
              path: "projects",
              reflect_url: "http://server/api/reflect/connectors/1/projects"
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

        projects = connector.lookup(%w(projects), context)

        expect(projects.reflect(context)).to eq({
          label: "Projects",
          path: "projects",
          reflect_url: "http://server/api/reflect/connectors/1/projects",
          type: :entity_set,
          protocol: [:query],
          entities: [
            {
              label: "my project",
              path: "projects/495",
              type: :entity,
              reflect_url: "http://server/api/reflect/connectors/1/projects/495"
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

        project = connector.lookup %w(projects 495), context

        expect(project.reflect(context)).to eq({
          label: "my project",
          path: "projects/495",
          reflect_url: "http://server/api/reflect/connectors/1/projects/495",
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
              reflect_url: "http://server/api/reflect/connectors/1/projects/495/call_flows",
            },
            "phone_book" => {
              label: "Phone Book",
              type: :entity_set,
              path: "projects/495/phone_book",
              reflect_url: "http://server/api/reflect/connectors/1/projects/495/phone_book",
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

        call_flows = connector.lookup %w(projects 495 call_flows), context

        expect(call_flows.reflect(context)).to eq({
          label: "Call flows",
          path: "projects/495/call_flows",
          reflect_url: "http://server/api/reflect/connectors/1/projects/495/call_flows",
          type: :entity_set,
          protocol: [:query],
          entities: [{
            label: "my flow",
            path: "projects/495/call_flows/740",
            type: :entity,
            reflect_url: "http://server/api/reflect/connectors/1/projects/495/call_flows/740",
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

        call_flow = connector.lookup %w(projects 495 call_flows 740), context

        expect(call_flow.reflect(context)).to eq({
          label: "my flow",
          path: "projects/495/call_flows/740",
          reflect_url: "http://server/api/reflect/connectors/1/projects/495/call_flows/740",
          type: :entity,
          properties: {
            id: { label: "Id", type: :integer },
            name: { label: "Name", type: :string}
          },
          actions: {
            "call"=> {
              label: "Call",
              path: "projects/495/call_flows/740/$actions/call",
              reflect_url: "http://server/api/reflect/connectors/1/projects/495/call_flows/740/$actions/call",
            }
          },
          events: {
            "call_finished" => {
              label: "Call finished",
              path: "projects/495/call_flows/740/$events/call_finished",
              reflect_url: "http://server/api/reflect/connectors/1/projects/495/call_flows/740/$events/call_finished"
            },
            "call_done" => {
              label: "Call done",
              path: "projects/495/call_flows/740/$events/call_done",
              reflect_url: "http://server/api/reflect/connectors/1/projects/495/call_flows/740/$events/call_done"
            },
            "call_completed" => {
              label: "Call completed",
              path: "projects/495/call_flows/740/$events/call_completed",
              reflect_url: "http://server/api/reflect/connectors/1/projects/495/call_flows/740/$events/call_completed"
            },
            "call_failed" => {
              label: "Call failed",
              path: "projects/495/call_flows/740/$events/call_failed",
              reflect_url: "http://server/api/reflect/connectors/1/projects/495/call_flows/740/$events/call_failed"
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

        event = connector.lookup %w(projects 495 call_flows 740 $events call_finished), context

        expect(event.reflect(context)).to eq({
          label: "Call finished",
          args: {
            address: {type: :string, label: "Phone Number"},
            status: {type: :string, label: "Status"},
            vars: {
              type: {
                kind: :struct,
                members: {
                  "name" => {type: :string},
                  "age" => {type: :string},
                }
              }
            }
          }
        })
      end

      it "reflects on call flow call failed event" do
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495.json").
          to_return(:status => 200, :body => %({"id": 495,"contact_vars":["name","age"]}), :headers => {})
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495/call_flows/740.json").
          to_return(:status => 200, :body => %({
            "id": 740,
            "name": "my flow"
          }), :headers => {})

        event = connector.lookup %w(projects 495 call_flows 740 $events call_failed), context

        expect(event.reflect(context)).to eq({
          label: "Call failed",
          args: {
            address: {type: :string, label: "Phone Number"},
            fail_reason: {type: :string, label: "Fail reason"},
            status: {type: :string, label: "Status"},
            vars: {
              type: {
                kind: :struct,
                members: {
                  "name" => {type: :string},
                  "age" => {type: :string},
                }
              }
            }
          }
        })
      end

      it "reflects on call flow call done event" do
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495.json").
          to_return(:status => 200, :body => %({"id": 495,"contact_vars":["name","age"]}), :headers => {})
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495/call_flows/740.json").
          to_return(:status => 200, :body => %({
            "id": 740,
            "name": "my flow"
          }), :headers => {})

        event = connector.lookup %w(projects 495 call_flows 740 $events call_done), context

        expect(event.reflect(context)).to eq({
          label: "Call done",
          args: {
            address: {type: :string, label: "Phone Number"},
            fail_reason: {type: :string, label: "Fail reason (if any)"},
            status: {type: :string, label: "Status"},
            vars: {
              type: {
                kind: :struct,
                members: {
                  "name" => {type: :string},
                  "age" => {type: :string},
                }
              }
            }
          }
        })
      end

      it "reflects on call" do
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495.json").
          to_return(:status => 200, :body => %({
            "id": 495,
            "name": "my project",
            "call_flows": [{
              "id": 740,
              "name": "my flow"}],
            "contact_vars":["name","age"]
          }), :headers => {})
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495/call_flows/740.json").
          to_return(:status => 200, :body => %({
            "id": 740,
            "name": "my flow"
          }), :headers => {})
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/channels.json").
          to_return(:status => 200, :body => %(["channel1"]), :headers => {})

        call = connector.lookup %w(projects 495 call_flows 740 $actions call), context

        expect(call.reflect(context)).to eq({
          label:"Call",
          args: {
            channel: {
              type: {
                kind: :enum,
                value_type: :string,
                members: [{value: "channel1", label: "channel1"}]
              },
              label: "Channel"
            },
            phone_number: {
              type: "string",
              label: "Phone Number"
            },
            vars: {
              type: {
                kind: :struct,
                members: {
                  "name" => {
                    type: :string,
                  },
                  "age" => {
                    type: :string,
                  },
                },
                open: true
              }
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
            "call_flows": [{"id": 740, "name": "my flow"}]
          }), :headers => {})
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495/call_flows/740.json").
          to_return(:status => 200, :body => %({
            "id": 740,
            "name": "my flow"
          }), :headers => {})
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/call?address=&channel=Channel&call_flow_id=740").
         to_return(:status => 200, :body => %({"call_id":755961,"state":"queued"}), :headers => {})

        call = connector.lookup %w(projects 495 call_flows 740 $actions call), context

        response = call.invoke({'channel' => 'Channel', 'address' => '123'}, context)
        expect(response).to eq({
          "call_id" => 755961,
          "state" => "queued"
        })
      end

      it "invokes with vars" do
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495.json").
          to_return(:status => 200, :body => %({
            "id": 495,
            "name": "my project",
            "call_flows": [{"id": 740, "name": "my flow"}]
          }), :headers => {})
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495/call_flows/740.json").
          to_return(:status => 200, :body => %({
            "id": 740,
            "name": "my flow"
          }), :headers => {})
        stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/call?address=&channel=Channel&call_flow_id=740&vars[foo]=1&vars[bar]=2").
         to_return(:status => 200, :body => %({"call_id":755961,"state":"queued"}), :headers => {})

        call = connector.lookup %w(projects 495 call_flows 740 $actions call), context

        response = call.invoke({'channel' => 'Channel', 'address' => '123', 'vars' => {'foo' => '1', 'bar' => '2'}}, context)
        expect(response).to eq({
          "call_id" => 755961,
          "state" => "queued"
        })
      end
    end

    describe "phone_book" do
      describe "query" do
        it "should return contact variables" do
          stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495.json").
            to_return(status: 200, body: %({
                "id": 495,
                "name": "my project"
              }), headers: {})

          stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495/contacts.json").
            to_return(:status => 200, :body => %(
                [
                  {
                    "id": 1,
                    "addresses": ["12345", "67890"],
                    "vars": {"foo": "bar"}
                  }
                ]), :headers => {})

          phone_book = connector.lookup %w(projects 495 phone_book), context

          response = phone_book.query({}, context, {})
          response = response[:items].map {|contact| contact.raw(context) }
          expect(response).to eq([
            {
              id: 1,
              address: "12345",
              foo: "bar"
            },
            {
              id: 1,
              address: "67890",
              foo: "bar"
            }
          ])
        end

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

          phone_book = connector.lookup %w(projects 495 phone_book), context

          response = phone_book.query({address: "12345"}, context, {})
          response = response[:items].map {|contact| contact.raw(context) }
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

        it "should return an empty set when filters don't match contacts" do
          stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495.json").
            to_return(status: 200, body: %({
                "id": 495,
                "name": "my project"
              }), headers: {})

          stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495/contacts/by_address/12345.json").
            to_return(:status => 404, :body => "", :headers => {})

          phone_book = connector.lookup %w(projects 495 phone_book), context

          response = phone_book.query({address: "12345"}, context, {})
          expect(response).to eq({items: []})
        end
      end

      describe "insert" do
        it "should post a new contact" do
          stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495.json").
            to_return(status: 200, body: %({
                "id": 495,
                "name": "my project"
              }), headers: {})

          stub_request(:post, "https://jdoe:1234@verboice.instedd.org/api/projects/495/contacts.json")

          phone_book = connector.lookup %w(projects 495 phone_book), context
          phone_book.insert({"address" => "12345", "foo" => "bar"}, context)

          expect(a_request(:post, "https://jdoe:1234@verboice.instedd.org/api/projects/495/contacts.json").
                 with(:body => {:address => '12345', :vars => {:foo => "bar"}})).to have_been_made
        end
      end

      describe "update" do
        it "should update a contact by address" do
          stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/495.json").
            to_return(status: 200, body: %({
                "id": 495,
                "name": "my project"
              }), headers: {})

          stub_request(:put, "https://jdoe:1234@verboice.instedd.org/api/projects/495/contacts/by_address/12345.json")

          phone_book = connector.lookup %w(projects 495 phone_book), context
          phone_book.update({"address" => "12345"}, {"foo" => "bar"}, context)

          expect(a_request(:put, "https://jdoe:1234@verboice.instedd.org/api/projects/495/contacts/by_address/12345.json").
                 with(:body => {:vars => {:foo => "bar"}})).to have_been_made
        end
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
        expect(connector.reflect(context)).to eq({
          label: "foo",
          path: "",
          reflect_url: "http://server/api/reflect/connectors/1",
          type: :entity,
          properties: {
            "projects" => {
              label: "Projects",
              type: :entity_set,
              path: "projects",
              reflect_url: "http://server/api/reflect/connectors/1/projects",
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

        expect(projects.reflect(context)).to eq({
          label: "Projects",
          path: "projects",
          reflect_url: "http://server/api/reflect/connectors/1/projects",
          type: :entity_set,
          protocol: [:query],
          entities: [
            {
              label: "my project",
              path: "projects/495",
              type: :entity,
              reflect_url: "http://server/api/reflect/connectors/1/projects/495"
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

        projects = connector.lookup %w(projects 495), context

        expect(projects.reflect(context)).to eq({
          label: "my project",
          path: "projects/495",
          reflect_url: "http://server/api/reflect/connectors/1/projects/495",
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
              reflect_url: "http://server/api/reflect/connectors/1/projects/495/call_flows",
            },
            "phone_book" => {
              label: "Phone Book",
              type: :entity_set,
              path: "projects/495/phone_book",
              reflect_url: "http://server/api/reflect/connectors/1/projects/495/phone_book",
            }
          }
        })
      end

      it "reflects on call flow" do
        stub_request(:get, "https://verboice.instedd.org/api/projects/495.json").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(status: 200, body: %({
            "id": 495,
            "name": "my project",
            "call_flows": [{"id": 740, "name": "my flow"}]
            }), headers: {})
        stub_request(:get, "https://verboice.instedd.org/api/projects/495/call_flows/740.json").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(status: 200, body: %({
            "id": 740, "name": "my flow"}), headers: {})

        call_flow = connector.lookup %w(projects 495 call_flows 740), context

        expect(call_flow.reflect(context)).to eq({
          label: "my flow",
          path: "projects/495/call_flows/740",
          reflect_url: "http://server/api/reflect/connectors/1/projects/495/call_flows/740",
          type: :entity,
          properties: {
            id: { label: "Id", type: :integer },
            name: { label: "Name", type: :string}
          },
          actions: {
            "call"=> {
              label: "Call",
              path: "projects/495/call_flows/740/$actions/call",
              reflect_url: "http://server/api/reflect/connectors/1/projects/495/call_flows/740/$actions/call",
            }
          },
          events: {
            "call_finished" => {
              label: "Call finished",
              path: "projects/495/call_flows/740/$events/call_finished",
              reflect_url: "http://server/api/reflect/connectors/1/projects/495/call_flows/740/$events/call_finished"
            },
            "call_done" => {
              label: "Call done",
              path: "projects/495/call_flows/740/$events/call_done",
              reflect_url: "http://server/api/reflect/connectors/1/projects/495/call_flows/740/$events/call_done"
            },
            "call_completed" => {
              label: "Call completed",
              path: "projects/495/call_flows/740/$events/call_completed",
              reflect_url: "http://server/api/reflect/connectors/1/projects/495/call_flows/740/$events/call_completed"
            },
            "call_failed" => {
              label: "Call failed",
              path: "projects/495/call_flows/740/$events/call_failed",
              reflect_url: "http://server/api/reflect/connectors/1/projects/495/call_flows/740/$events/call_failed"
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
            "call_flows": [{"id": 740, "name": "my flow"}],
            "contact_vars":["name","age"]
            }), headers: {})
        stub_request(:get, "https://verboice.instedd.org/api/projects/495/call_flows/740.json").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(status: 200, body: %({
            "id": 740, "name": "my flow"}), headers: {})
        stub_request(:get, "https://verboice.instedd.org/api/channels.json").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(:status => 200, :body => %(["channel1"]), :headers => {})

        call = connector.lookup %w(projects 495 call_flows 740 $actions call), context

        expect(call.reflect(context)).to eq({
          label:"Call",
          args: {
            channel: {
              type: {
                kind: :enum,
                value_type: :string,
                members: [{value: "channel1", label: "channel1"}]
              },
              label: "Channel"
            },
            phone_number: {
              type: "string",
              label: "Phone Number"
            },
            vars: {
              type: {
                kind: :struct,
                members: {
                  "name" => {
                    type: :string,
                  },
                  "age" => {
                    type: :string,
                  },
                },
                open: true
              }
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
            "call_flows": [{"id": 740, "name": "my flow"}],
            "contact_vars":["name","age"]
            }), headers: {})
        stub_request(:get, "https://verboice.instedd.org/api/projects/495/call_flows/740.json").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(status: 200, body: %({
            "id": 740, "name": "my flow"}), headers: {})
        stub_request(:get, "https://verboice.instedd.org/api/call?address=123&channel=Channel&call_flow_id=740").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(:status => 200, :body => %({"call_id":755961,"state":"queued"}), :headers => {})

        call = connector.lookup %w(projects 495 call_flows 740 $actions call), context

        response = call.invoke({'channel' => 'Channel', 'phone_number' => '123'}, context)
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
            "call_flows": [{"id": 740, "name": "my flow"}],
            "contact_vars":["name","age"]
            }), headers: {})
        stub_request(:get, "https://verboice.instedd.org/api/projects/495/call_flows/740.json").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(status: 200, body: %({
            "id": 740, "name": "my flow"}), headers: {})
        stub_request(:get, "https://verboice.instedd.org/api/call?address=123%20456&channel=Channel%20123&call_flow_id=740").
          with(:headers => {'Authorization'=>'Bearer This is a guisso auth token!'}).
          to_return(:status => 200, :body => %({"call_id":755961,"state":"queued"}), :headers => {})

        call = connector.lookup %w(projects 495 call_flows 740 $actions call), context

        response = call.invoke({'channel' => 'Channel 123', 'phone_number' => '123 456'}, context)
        expect(response).to be_present
      end
    end
  end

  describe "perform subscribed events" do
    before(:each) do
      stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/1.json").
        to_return(status: 200, body: %({
            "id": 2,
            "name": "my project",
            "call_flows": [{
              "id": 740,
              "name": "my flow"
            }],
            "schedules": []
          }), headers: {})
      stub_request(:get, "https://jdoe:1234@verboice.instedd.org/api/projects/1/call_flows/6.json").
        to_return(status: 200, body: %({
            "id": 740,
            "name": "my flow"
          }), headers: {})
    end

    let(:verboice_connector) { VerboiceConnector.make! username: 'jdoe', password: '1234', user: user }

    let!(:event_handler_1) { EventHandler.create!(
      connector: verboice_connector,
      event: "projects/1/call_flows/6/$events/call_finished",
      target_connector: verboice_connector,
      action: "projects/1/call_flows/6/$events/call_finished",
    )}

    let!(:event_handler_2) { EventHandler.create!(
      connector: verboice_connector,
      event: "projects/1/call_flows/6/$events/call_finished",
      target_connector: verboice_connector,
      action: "projects/1/call_flows/6/$events/call_finished",
    )}


    it "should invoke event handlers when processing a queued job" do
      data = {"project_id"=>1, "call_flow_id"=>6, "address"=>"17772632588", "vars"=>{"age"=>"20"}}.to_json
      trigger_count = 0
      allow_any_instance_of(EventHandler).to receive(:trigger) do |data|
        trigger_count+=1
      end

      Connector::NotifyJob.perform(verboice_connector.id, "projects/1/call_flows/6/$events/call_finished",  data)

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
