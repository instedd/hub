describe CDXConnector do
  describe "reference counting" do
    let!(:connector) { CDXConnector.make! }
    let(:user) { connector.user }

    let(:event) {
      connector.lookup_path "filters/12345/$events/new_data", nil
    }


    class CDXMockAction
      attr_reader :connector

      def initialize(connector)
        @connector = connector
      end

      def path
        "foo"
      end
    end

    it "should increse on subscribe" do
      # this allow to have mock action in connector
      allow_any_instance_of(EventHandler).to receive(:notify_action_created)

      expect {
        event.subscribe(CDXMockAction.new(connector), "binding", user)
      }.to change {
        event.reference_count
      }.from(0).to(1)
    end

    it "should decrease on unsubscribe" do
      # this allow to have mock action in connector
      allow_any_instance_of(EventHandler).to receive(:notify_action_created)

      first = event.subscribe(CDXMockAction.new(connector), "binding", user)
      second = nil

      expect {
        second = event.subscribe(CDXMockAction.new(connector), "binding", user)
      }.to change {
        event.reference_count
      }.by(1)

      expect {
        second.destroy
      }.to change {
        event.reference_count
      }.by(-1)

      expect {
        first.destroy
      }.to change {
        event.reference_count
      }.by(-1)
    end
  end
end
