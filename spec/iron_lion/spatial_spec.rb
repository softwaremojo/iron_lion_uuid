# frozen_string_literal: true

RSpec.describe "Spatial fields" do
  # Reference cells from the H3 documentation.
  let(:cell) { "8928308280fffff" }
  let(:parent) { "8828308281fffff" }

  describe "h3:" do
    let(:format) { IronLion.define { cell h3: 9 } }

    def cell_for(record = nil, **values) = format.generate(record, **values).cell

    it "stores only the base cell and digits: 7 + 3 bits per resolution" do
      expect(format.fields[1].bits).to eq(34)
      expect(IronLion.define { cell h3: 0 }.fields[1].bits).to eq(7)
      expect(IronLion.define { cell h3: 15 }.fields[1].bits).to eq(52)
      expect(format.to_h[:fields][1]).to include(kind: :h3, bits: 34, resolution: 9)
    end

    it "round-trips a cell as its canonical H3 string" do
      id = format.generate(cell: cell)
      expect(IronLion.parse(id.to_s, format:).cell).to eq(cell)
    end

    it "accepts integers and hex in any case or with 0x" do
      [cell.to_i(16), cell.upcase, "0x#{cell}", " #{cell} "].each { expect(cell_for(cell: _1)).to eq(cell) }
    end

    it "trims finer cells to their parent, like cellToParent" do
      expect(IronLion.define { cell h3: 8 }.generate(cell: cell).cell).to eq(parent)
    end

    it "reads the cell from the record" do
      expect(cell_for(Struct.new(:cell).new(cell))).to eq(cell)
      expect(cell_for(Struct.new(:iron_lion_cell, :cell).new(cell, "nope"))).to eq(cell)
    end

    describe "mistakes" do
      def rejects(value, message)
        expect { cell_for(cell: value) }.to raise_error(IronLion::InvalidValueError, message)
      end

      it { rejects(parent, /resolution 8 cell, coarser than resolution 9/) }
      it { rejects("not hex", /not an H3 index/) }
      it { rejects("0", /not an H3 cell index/) }
      it { rejects((1 << 63) | cell.to_i(16), /not an H3 cell index/) }
      it { rejects([37.77, -122.42], /is a coordinate/) }
      it { rejects(1.5, /not an H3 index/) }

      it "rejects resolutions H3 does not have" do
        expect do
          IronLion.define do
            cell h3: 16
          end
        end.to raise_error(IronLion::ConfigurationError, /h3: 0..15 \(resolution\)/)
      end
    end
  end

  describe "geohash:" do
    let(:format) { IronLion.define { spot geohash: 11 } }

    # Wikipedia's geohash example: Jutland, Denmark.
    let(:jutland) { [57.64911, 10.40744] }

    def spot_for(record = nil, **values) = format.generate(record, **values).spot

    it "takes 5 bits per character" do
      expect(format.fields[1].bits).to eq(55)
      expect(format.to_h[:fields][1]).to include(kind: :geohash, bits: 55, chars: 11)
    end

    it "stores exactly the geohash of a coordinate" do
      expect(spot_for(spot: jutland).geohash).to eq("u4pruydqqvj")
    end

    it "decodes to the cell centre, within the cell's error" do
      location = IronLion.parse(format.generate(spot: jutland).to_s, format:).spot
      expect(location.latitude).to be_within(location.latitude_error).of(jutland[0])
      expect(location.longitude).to be_within(location.longitude_error).of(jutland[1])
      expect(location.to_a).to eq([location.lat, location.lng])
      expect(location.to_s).to eq("u4pruydqqvj")
    end

    it "decodes a known geohash to its known centre" do
      location = IronLion.define { spot geohash: 5 }.generate(spot: "ezs42").spot
      expect(location.to_a.map { _1.round(3) }).to eq([42.605, -5.603])
    end

    it "accepts the shapes positions come in" do
      point = Struct.new(:lat, :lng).new(*jutland)
      inputs = [jutland, { lat: jutland[0], lon: jutland[1] }, { "latitude" => jutland[0], "longitude" => jutland[1] },
                point, "U4PRUYDQQVJXYZ", :u4pruydqqvj, spot_for(spot: jutland)]
      inputs.each { expect(spot_for(spot: _1).geohash).to eq("u4pruydqqvj") }
    end

    it "infers the position from a record's own coordinates" do
      shop = Struct.new(:latitude, :longitude).new(*jutland)
      expect(spot_for(shop).geohash).to eq("u4pruydqqvj")
    end

    it "prefers a named attribute to the record's coordinates" do
      shop = Struct.new(:spot, :latitude, :longitude).new("ezs42ezs42e", *jutland)
      expect(spot_for(shop).geohash).to eq("ezs42ezs42e")
    end

    it "handles the edges of the map" do
      expect(spot_for(spot: [90, 180]).geohash).to eq("zzzzzzzzzzz")
      expect(spot_for(spot: [-90, -180]).geohash).to eq("00000000000")
    end

    it "shows the geohash when an id is inspected" do
      expect(format.generate(spot: jutland).inspect).to include("spot=u4pruydqqvj")
    end

    describe "mistakes" do
      def rejects(value, message)
        expect { spot_for(spot: value) }.to raise_error(IronLion::InvalidValueError, message)
      end

      it { rejects([91, 0], /latitude 91, outside -90..90/) }
      it { rejects([0, 181], /longitude 181, outside -180..180/) }
      it { rejects("u4pru", /5-character geohash; 11 are needed/) }
      it { rejects("u4pruydqqva", /not a geohash/) }
      it { rejects(42, /not a position/) }

      it "names the coordinate methods it looked for" do
        expect { spot_for(Struct.new(:name).new("x")) }
          .to raise_error(IronLion::MissingValueError, %r{#iron_lion_spot, #spot, or its own #latitude/#longitude})
      end
    end
  end
end
