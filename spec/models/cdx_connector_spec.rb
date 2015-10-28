require "erb"

describe CDXConnector do
  describe "reference counting" do
    include ERB::Util

    let!(:connector) { CDXConnector.make! }
    let(:user) { connector.user }
    let(:request_context) { RequestContext.new(user) }

    let(:event) {
      connector.lookup_path "filters/12345/$events/new_event", nil
    }

    def base_api_url
      URI(connector.url)
    end

    def with_oauth_token(stub_request)
      stub_request.with(headers: {"Authorization" => "Bearer #{connector.oauth_token}"})
    end

    class CDXMockAction
      attr_reader :connector

      def initialize(connector)
        @connector = connector
      end

      def path
        "foo"
      end
    end

    it "should increse on subscribe and record subscriber id" do
      # this allow to have mock action in connector
      allow_any_instance_of(EventHandler).to receive(:notify_action_created)

      stub_subscribe = with_oauth_token(stub_request(:post, "#{base_api_url}/filters/12345/subscribers.json")).
        to_return(status: 200, body: %({"id": 56}))

      expect {
        event.subscribe(CDXMockAction.new(connector), "binding", request_context)
      }.to change {
        event.reference_count
      }.from(0).to(1)

      connector.reload

      expect(event.subscriber_id).to eq(56)
      assert_requested stub_subscribe
    end

    it "should decrease on unsubscribe" do
      # this allow to have mock action in connector
      allow_any_instance_of(EventHandler).to receive(:notify_action_created)

      stub_subscribe = with_oauth_token(stub_request(:post, "#{base_api_url}/filters/12345/subscribers.json")).
        to_return(status: 200, body: %({"id": 34}))

      first = event.subscribe(CDXMockAction.new(connector), "binding", request_context)
      second = nil

      remove_request_stub(stub_subscribe)

      expect {
        second = event.subscribe(CDXMockAction.new(connector), "binding", request_context)
      }.to change {
        event.reference_count
      }.by(1)

      expect {
        second.destroy
      }.to change {
        event.reference_count
      }.by(-1)

      stub_unsubscribe = with_oauth_token(stub_request(:delete, "#{base_api_url}/filters/12345/subscribers/34")).
        to_return(status: 200, body: %({"id": 56}))

      expect {
        first.destroy
      }.to change {
        event.reference_count
      }.by(-1)

      assert_requested stub_unsubscribe
    end

    it "should'n fail on unsubscribe if the subscriber is already deleted" do
      # this allow to have mock action in connector
      allow_any_instance_of(EventHandler).to receive(:notify_action_created)

      stub_subscribe = with_oauth_token(stub_request(:post, "#{base_api_url}/filters/12345/subscribers.json")).
        to_return(status: 200, body: %({"id": 34}))

      first = event.subscribe(CDXMockAction.new(connector), "binding", request_context)

      remove_request_stub(stub_subscribe)

      stub_unsubscribe = with_oauth_token(stub_request(:delete, "#{base_api_url}/filters/12345/subscribers/34")).
        to_return(status: [404, "not found"])

      expect {
        first.destroy
      }.to change {
        event.reference_count
      }.by(-1)

      assert_requested stub_unsubscribe
    end
  end
end
