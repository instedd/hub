describe JsonMapper do
  it "maps raw value" do
    mapper = JsonMapper.new([])
    source = 123
    expect(mapper.map(source)).to eq(123)
  end

  it "maps single value from struct" do
    mapper = JsonMapper.new("x")
    source = {"x" => 1, "y" => 2}
    expect(mapper.map(source)).to eq(1)
  end

  it "maps single value from path" do
    mapper = JsonMapper.new(["x", 1])
    source = {"x" => [0, 1, 2], "y" => 2}
    expect(mapper.map(source)).to eq(1)
  end

  it "maps struct from simple properties" do
    mapper = JsonMapper.new({"type" => "struct", "members" => {"foo" => "x", "bar" => "y"}})
    source = {"x" => 1, "y" => 2}
    expect(mapper.map(source)).to eq({"foo" => 1, "bar" => 2})
  end

  it "maps properties inside a struct" do
    mapper = JsonMapper.new({
      "type" => "struct",
      "members" => {
        "foo" => {
          "type" => "struct",
          "members" => {"value" => "x"}
        }
      }
    })
    source = {"x" => 1, "y" => 2}
    expect(mapper.map(source)).to eq({"foo" => {"value" => 1}})
  end

  it "maps with path inside a struct" do
    mapper = JsonMapper.new({
      "type" => "struct",
      "members" => {
        "foo" => ["x", "y", "z"]
      }
    })
    source = {"x" => {"y" => {"z" => 123}}}
    expect(mapper.map(source)).to eq({"foo" => 123})
  end

  it "maps with path with array index" do
    mapper = JsonMapper.new({
      "type" => "struct",
      "members" => {
        "foo" => ["x", 0, "y"]
      }
    })
    source = {"x" => [{"y" => 123}]}
    expect(mapper.map(source)).to eq({"foo" => 123})
  end
end
