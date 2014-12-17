describe ResourceMapConnector do
  let(:user) { User.make }

  describe "initialization" do
    it "should set defaults for new connector" do
      connector = ResourceMapConnector.make
      expect(connector.url).to eq("https://resourcemap.instedd.org")
      expect(connector.shared?).to eq(false)
    end
  end
end
