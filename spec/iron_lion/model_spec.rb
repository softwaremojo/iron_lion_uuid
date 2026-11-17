# frozen_string_literal: true

RSpec.describe "The model field" do
  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, "config", "iron_lion.yml") }

  after { FileUtils.remove_entry(dir) }

  describe "in a format" do
    let(:format) { IronLion.define { model bits: 4 } }

    it "takes the record's class and decodes back to it" do
      id = format.generate(Fixtures::Order.new)
      expect(id.model).to eq(Fixtures::Order)
    end

    it "ignores a record attribute called model" do
      expect(format.generate(Fixtures::Car.new("Corolla")).model).to eq(Fixtures::Car)
    end

    it "refuses anonymous classes, which have no name to number" do
      expect { format.generate(Struct.new(:a).new) }.to raise_error(IronLion::InvalidValueError, /anonymous/)
    end

    it "honours #iron_lion_model on the record" do
      record = Struct.new(:iron_lion_model).new(Fixtures::User)
      expect(format.generate(record).model).to eq(Fixtures::User)
    end

    it "accepts a class, a name, an instance or a raw number" do
      expect(format.generate(model: Fixtures::Order).model).to eq(Fixtures::Order)
      expect(format.generate(model: "Fixtures::User").model).to eq(Fixtures::User)
      expect(format.generate(model: Fixtures::User.new).model).to eq(Fixtures::User)
      expect(format.generate(model: 9).model).to eq(9)
    end

    it "lets a class answer iron_lion_model_id for itself" do
      expect(format.generate(model: Fixtures::Invoice).to_h[:model]).to eq(7)
    end

    it "returns the name when the class is not loaded" do
      expect(format.generate(model: "Archived::Thing").model).to eq("Archived::Thing")
    end

    it "fills its numbers up to the field's capacity" do
      15.times { format.generate(model: "Model#{_1}") }
      expect { format.generate(model: "OneTooMany") }.to raise_error(IronLion::OverflowError, /table is full/)
    end
  end

  describe IronLion::ModelTable do
    it "numbers models from 1 in first-seen order" do
      table = described_class.new
      expect(%w[User Order User].map { table.id_for(_1) }).to eq([1, 2, 1])
      expect(table.name_for(2)).to eq("Order")
    end

    it "writes an append-only YAML file, creating its directory" do
      table = described_class.new(path)
      table.id_for("User")
      table.id_for("Admin::User")
      expect(File.read(path)).to eq(<<~YAML)
        # IronLion model ids. Append-only: once issued, an id belongs to that
        # model forever. Rename a model by changing its key, never its number.
        models:
          "User": 1
          "Admin::User": 2
      YAML
      expect(described_class.new(path).to_h).to eq("User" => 1, "Admin::User" => 2)
    end

    it "sees ids assigned by another process" do
      mine = described_class.new(path)
      mine.id_for("User")
      described_class.new(path).id_for("Order")
      expect(mine.id_for("Invoice")).to eq(3)
      expect(described_class.new(path).name_for(2)).to eq("Order")
    end

    it "raises for unknown models when it may not assign" do
      described_class.new(path).id_for("User")
      table = described_class.new(path, assign: false)
      expect(table.id_for("User")).to eq(1)
      expect { table.id_for("Order") }.to raise_error(IronLion::UnknownModelError, /Order has no IronLion model id/)
    end

    it "refuses a file that gives one id to two models" do
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "models:\n  User: 1\n  Order: 1\n")
      expect { described_class.new(path).id_for("User") }
        .to raise_error(IronLion::ConfigurationError, /gives id 1 to more than one model/)
    end

    it "can be named by path in the format" do
      format = IronLion.define { |f| f.model bits: 8, table: path }
      format.generate(model: "User")
      expect(File.read(path)).to include('"User": 1')
    end
  end
end
