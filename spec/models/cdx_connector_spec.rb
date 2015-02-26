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
      uri = URI(connector.url)
      connector.url.gsub("#{uri.scheme}://", "#{uri.scheme}://#{url_encode(connector.username)}:#{url_encode(connector.password)}@")
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

      stub_subscribe = stub_request(:post, "#{base_api_url}/filters/12345/subscribers.json").
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

      stub_subscribe = stub_request(:post, "#{base_api_url}/filters/12345/subscribers.json").
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

      stub_unsubscribe = stub_request(:delete, "#{base_api_url}/filters/12345/subscribers/34").
        to_return(status: 200, body: %({"id": 56}))

      expect {
        first.destroy
      }.to change {
        event.reference_count
      }.by(-1)

      assert_requested stub_unsubscribe
    end
  end
end
