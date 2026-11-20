# frozen_string_literal: true

RSpec.describe IronLion::Postgres, :postgres do
  let(:table) { IronLion::ModelTable.new }

  let(:format) do
    models = table
    IronLion.define do
      tenant    bits: 16
      model     bits: 8, table: models
      node      bits: 8
      subdomain chars: 5
      sequence  bits: 12
    end
  end

  let(:spatial) do
    IronLion.define do
      cell h3: 9
      spot geohash: 8
    end
  end

  let(:postgres) { described_class.new(format) }

  def mint(**args)
    call = args.map { |name, _| "#{name} => $#{args.keys.index(name) + 1}" }.join(", ")
    value("SELECT iron_lion_uuid(#{call})", *args.values)
  end

  def decoded(uuid, with: format) = IronLion.parse(uuid, format: with)

  def comparable(id) = id.to_h.except(:created_at, :sequence, :random)

  describe "iron_lion_uuid()" do
    before { install(format) }

    it "mints ids that Ruby decodes field for field" do
      id = decoded(mint(tenant: 4211, model: 3, node: 53, subdomain: "AcMe"))
      expect(id.to_h).to include(tenant: 4211, node: 53, subdomain: "acme")
      expect(id.to_h[:model]).to eq(3)
    end

    it "packs bits exactly as Ruby does" do
      values = { tenant: 65_535, model: 255, node: 0, subdomain: "zzzzz" }
      expect(comparable(decoded(mint(**values)))).to eq(comparable(format.generate(**values)))
    end

    it "stamps the database clock and counts with iron_lion_seq" do
      before = Time.now
      ids = Array.new(50) { decoded(mint(tenant: 1, model: 1, node: 1, subdomain: "a")) }
      expect(ids.first.created_at).to be_between(Time.at(before.to_i), Time.now + 1)
      expect(ids.map(&:sequence)).to eq((1..50).to_a)
      expect(ids.sort).to eq(ids)
    end

    it "backdates with created_at" do
      past = Time.utc(2020, 2, 29, 12, 0, 0.25r)
      uuid = value("SELECT iron_lion_uuid(tenant => 1, model => 1, node => 1, subdomain => 'a', created_at => $1)",
                   past.iso8601(3))
      expect(decoded(uuid).created_at).to eq(past)
    end

    it "takes a random counter for an explicit created_at, leaving iron_lion_seq alone" do
      mint(tenant: 1, model: 1, node: 1, subdomain: "a")
      sequence_state = -> { sql("SELECT last_value, is_called FROM iron_lion_seq") }
      before = sequence_state.call

      value("SELECT iron_lion_uuid(tenant => 1, model => 1, node => 1, subdomain => 'a', created_at => now())")
      expect(sequence_state.call).to eq(before)
    end

    it "falls back to iron_lion.* settings, the database's ENV" do
      sql("SET LOCAL iron_lion.node = '53'; SET LOCAL iron_lion.tenant = '9'")
      expect(decoded(mint(model: 1, subdomain: "a")).to_h).to include(node: 53, tenant: 9)
    end

    describe "mistakes" do
      def rejects(message, **args)
        db.exec("SAVEPOINT attempt")
        expect { mint(**args) }.to raise_error(PG::Error, message)
      ensure
        db.exec("ROLLBACK TO SAVEPOINT attempt")
      end

      let(:valid) { { tenant: 1, model: 1, node: 1, subdomain: "a" } }

      it { rejects(/No value for node\. IronLion looked in/, **valid.except(:node)) }
      it { rejects(/tenant 65536 does not fit in 16 bits \(0\.\.65535\)/, **valid, tenant: 65_536) }
      it { rejects(/tenant -1 does not fit/, **valid, tenant: -1) }
      it { rejects(/subdomain "my-sh" may only contain letters and digits/, **valid, subdomain: "my-sh") }
      it { rejects(/subdomain "toolong" is longer than 5 characters/, **valid, subdomain: "toolong") }
    end
  end

  describe "a small counter" do
    # No random bits: within a millisecond, only the counter tells ids apart.
    let(:small) do
      IronLion.define do
        node     bits: 70
        sequence bits: 4
      end
    end

    before { install(small) }

    it "keeps 2^bits consecutive ids distinct, though the counter wraps" do
      ids = sql("SELECT iron_lion_uuid(node => 1) FROM generate_series(1, 16)").flatten
      expect(ids.uniq.size).to eq(16)
    end
  end

  describe "spatial fields" do
    before { install(spatial) }

    let(:cell) { "8928308280fffff" }

    it "stores H3 cells and geohashes as Ruby does" do
      values = { cell: cell, spot: "u4pruydq" }
      expect(comparable(decoded(mint(**values), with: spatial))).to eq(comparable(spatial.generate(**values)))
    end

    it "trims finer H3 cells to the field's resolution" do
      coarse = IronLion.define { cell h3: 8 }
      install(coarse)
      expect(decoded(mint(cell: cell), with: coarse).cell).to eq("8828308281fffff")
    end

    it "geohashes coordinates exactly as Ruby does" do
      random = Random.new(42)
      points = Array.new(200) do
        [Kernel.format("%.6f", (random.rand * 180) - 90), Kernel.format("%.6f", (random.rand * 360) - 180)]
      end
      points += [%w[90 180], %w[-90 -180], %w[0 0], %w[57.64911 10.40744]]

      points.each do |latitude, longitude|
        ruby = IronLion::Geohash.decode(IronLion::Geohash.encode([latitude.to_r, longitude.to_r], 11), 11).geohash
        expect(value("SELECT iron_lion_geohash($1, $2, 11)", latitude, longitude)).to eq(ruby)
      end
    end

    describe "mistakes" do
      def rejects(message, **args)
        db.exec("SAVEPOINT attempt")
        expect { mint(**args) }.to raise_error(PG::Error, message)
      ensure
        db.exec("ROLLBACK TO SAVEPOINT attempt")
      end

      it { rejects(/is a resolution 8 cell, coarser than resolution 9/, cell: "8828308281fffff", spot: "u4pruydq") }
      it { rejects(/is not an H3 cell index/, cell: "0", spot: "u4pruydq") }
      it { rejects(/is not an H3 index/, cell: "nope", spot: "u4pruydq") }
      it { rejects(/is a 5-character geohash; 8 are needed/, cell: cell, spot: "u4pru") }
      it { rejects(/is not a geohash/, cell: cell, spot: "u4pruyda") }
    end
  end

  describe "the insert trigger" do
    before do
      install(format)
      sql("CREATE TABLE orders (id uuid PRIMARY KEY, tenant_id bigint, subdomain text, note text)")
      db.exec(postgres.trigger_sql("orders", model: "Order"))
      sql("SET LOCAL iron_lion.node = '53'")
    end

    def insert(columns)
      names = columns.keys.join(", ")
      placeholders = Array.new(columns.size) { "$#{_1 + 1}" }.join(", ")
      value("INSERT INTO orders (#{names}) VALUES (#{placeholders}) RETURNING id", *columns.values)
    end

    it "fills a missing id from the row, as ActiveRecord inserts" do
      id = decoded(insert(tenant_id: 7, subdomain: "shop1"))
      expect(id.to_h).to include(tenant: 7, subdomain: "shop1", node: 53, model: "Order")
    end

    it "fills an explicit NULL id" do
      expect(decoded(insert(id: nil, tenant_id: 8, subdomain: "x")).tenant).to eq(8)
    end

    it "keeps an id that was supplied" do
      supplied = format.generate(model: "Order", tenant: 1, node: 2, subdomain: "keep").to_s
      expect(insert(id: supplied, tenant_id: 1, subdomain: "keep")).to eq(supplied)
    end

    it "numbers the model from the format's model table" do
      expect(table.to_h).to eq("Order" => 1)
    end

    it "prefers iron_lion_<field>, then <field>_id, then <field>" do
      sql("CREATE TABLE things (id uuid PRIMARY KEY, iron_lion_tenant int, tenant_id int, subdomain text)")
      db.exec(postgres.trigger_sql("things", model: 9))
      uuid = value("INSERT INTO things (iron_lion_tenant, tenant_id, subdomain) VALUES (1, 2, 'a') RETURNING id")
      expect(decoded(uuid).to_h).to include(tenant: 1, model: 9)
    end

    it "fills an id column with another name" do
      sql("CREATE TABLE events (uuid uuid PRIMARY KEY, tenant_id int, subdomain text)")
      db.exec(postgres.trigger_sql("events", model: 4, column: "uuid"))
      uuid = value("INSERT INTO events (tenant_id, subdomain) VALUES (5, 'ev') RETURNING uuid")
      expect(decoded(uuid).to_h).to include(tenant: 5, subdomain: "ev")
    end

    it "explains what the row was missing" do
      db.exec("SAVEPOINT attempt")
      expect { insert(subdomain: "x") }
        .to raise_error(PG::Error, /No value for tenant\..*from: resolvers don't run in the database/m)
    ensure
      db.exec("ROLLBACK TO SAVEPOINT attempt")
    end
  end

  describe "the insert trigger with spatial fields" do
    it "reads H3 from bigint columns and geohashes the row's coordinates" do
      install(spatial)
      sql("CREATE TABLE shops (id uuid PRIMARY KEY, cell bigint, latitude numeric, longitude numeric)")
      db.exec(described_class.new(spatial).trigger_sql("shops"))

      uuid = value(
        "INSERT INTO shops (cell, latitude, longitude) VALUES ($1, 57.64911, 10.40744) RETURNING id",
        "8928308280fffff".to_i(16)
      )
      id = decoded(uuid, with: spatial)
      expect(id.cell).to eq("8928308280fffff")
      expect(id.spot.geohash).to eq("u4pruydq")
    end
  end

  describe "SQL generation" do
    it "refuses a model for a format without a model field" do
      expect { described_class.new(spatial).trigger_sql("shops", model: "Shop") }
        .to raise_error(IronLion::ConfigurationError, /no model field/)
    end

    it "reinstalls cleanly after the format changes" do
      install(format)
      install(spatial)
      expect(decoded(mint(cell: "8928308280fffff", spot: "u4pruydq"), with: spatial).cell).to eq("8928308280fffff")
    end

    it "uninstalls everything" do
      install(format)
      db.exec(postgres.uninstall_sql)
      count = value("SELECT count(*) FROM pg_proc WHERE proname LIKE 'iron_lion%' AND " \
                    "pronamespace = 'iron_lion_spec'::regnamespace")
      expect(count).to eq("0")
      expect(value("SELECT to_regclass('iron_lion_spec.iron_lion_seq')")).to be_nil
    end
  end
end
