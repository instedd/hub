describe GoogleSpreadsheetsConnector do

  describe "filters match" do
    let(:worksheet) { GoogleSpreadsheetsConnector::Worksheet.new "parent", "gid", nil, nil }
    let(:row) { GoogleDrive::ListRow.new(nil, 0) }

    it "should match equal strings" do
      # Row will have an 'x' column with a value of 5
      allow(row).to receive(:[]).with('x') { "string" }
      filters = {"x" => "string"}
      expect(worksheet.row_matches_filters?(row, filters)).to be_truthy
    end

    it "should not match unequal strings" do
      allow(row).to receive(:[]).with('x') { "string" }
      filters = {"x" => "failure"}
      expect(worksheet.row_matches_filters?(row, filters)).to be_falsey
    end

    it "should match string to int" do
      allow(row).to receive(:[]).with('x') { "5" }
      filters = {"x" => 5}
      expect(worksheet.row_matches_filters?(row, filters)).to be_truthy
    end

    it "should match string to float" do
      allow(row).to receive(:[]).with('x') { "5" }
      filters = {"x" => 5.0}
      expect(worksheet.row_matches_filters?(row, filters)).to be_truthy
    end

    it "should match string to float with decimals" do
      allow(row).to receive(:[]).with('x') { "5.30" }
      filters = {"x" => 5.3}
      expect(worksheet.row_matches_filters?(row, filters)).to be_truthy
    end
  end

end
