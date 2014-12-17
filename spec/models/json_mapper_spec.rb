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

  it "maps literal value" do
    mapper = JsonMapper.new({
      "type" => "literal",
      "value" => [1, 2, 3]
    })
    expect(mapper.map(nil)).to eq([1, 2, 3])
  end

  it "maps verboice data" do
    mapper = JsonMapper.new({
      "type"=>"struct",
      "members"=>{
        "channel"=>
          {"type"=>"literal", "value"=>"callcentric"},
        "number"=>
          ["address"]
        }
    })

    source = {"project_id"=>1, "call_flow_id"=>4, "address"=>"17772632588", "vars"=>{"age"=>"20"}}
    expect(mapper.map(source)).to eq({"channel"=>"callcentric", "number"=> "17772632588"})
  end

  it "maps struct with nil bindings" do
    mapper = JsonMapper.new({"type" => "struct", "members" => {"foo" => {"type" => "literal", "value" => nil}, "bar" => "y"}})
    source = {"x" => 1, "y" => 2}
    expect(mapper.map(source)).to eq({"bar" => 2})
  end
end
