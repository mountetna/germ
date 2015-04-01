require 'hash_table'

describe HashTable do
  describe ".new :column" do
    it "allows you to set columns" do
      h = HashTable.new :columns => [ :one, :two, :three ]

      expect(h.columns).to eq([ :one, :two, :three ])
    end
  end
  describe ".comment" do
    it "allows you to set a comment character" do
      h = HashTable.new :comment => "#"
      h.parse "fixtures/commented.txt"

      expect(h.count).to eq(2)
      expect(h.columns).to eq([ :name, :breed, :owner, :created ])
    end
  end
  describe ".columns" do
    class HorseTable < HashTable
      columns :name, :coat_color, :height_in_hands
    end
    it "allows you set set class default columns" do
      h = HorseTable.new
      expect(h.columns).to eq [:name, :coat_color, :height_in_hands]
    end
    it "can be overriden via instance creation" do
      new_columns = [ :noom, :coot_color, :hooght_on_honds ]
      h = HorseTable.new :columns => new_columns
      expect(h.columns).to eq new_columns
    end
  end
  describe ".parse_mode" do 
    context "orig" do
      class DirtyTable < HashTable
        columns :name, :breed, :owner, :created
        parse_mode :orig
      end
      it "uses the original columns as given" do
        h = DirtyTable.new
        h.parse "fixtures/test_dirty_names.txt"

        expect(h.display_names.values).to eq([])
      end
    end
    context "parsed" do
      class DirtyTable2 < HashTable
        columns :name, :breed, :owner, :created
        parse_mode :parsed
      end
      it "uses the columns from the given file" do
        h = DirtyTable2.new
        h.parse "fixtures/test_dirty_names.txt"

        expect(h.count).to eq 3
        expect(h.display_names.values).to eq([ :Name, :Breed, :Owner, :Created ])
      end
    end
    context "noheader" do 
      class DirtyTable3 < HashTable
        columns :name, :breed, :owner, :created
        parse_mode :noheader
      end
      it "uses the original columns and does not look for a header in the file" do
        h = DirtyTable3.new
        h.parse "fixtures/test_noheader.txt"

        expect(h.count).to eq 3
      end
    end
  end
  describe ".types" do
    DEFAULT_TYPES = {:votes_a => :int, :votes_b => :int, :registered => :int}
    class ElectionResult < HashTable
      types DEFAULT_TYPES
    end
    it "allows you set set class default types" do
      e = ElectionResult.new
      expect(e.types).to eq(DEFAULT_TYPES)
    end
    it "can be overriden via instance creation" do
      new_types = { :votes_a => :float, :votes_b => :float, :registered => :int }
      e = ElectionResult.new :types => new_types
      expect(e.types).to eq new_types
    end
    it "adds new types rather than replacing" do
      new_types = { :a_name => :str }
      e = ElectionResult.new :types => new_types
      expect(e.types).to eq DEFAULT_TYPES.merge(new_types)
    end
    it "converts columns when parsed" do
      e = ElectionResult.new
      e.parse "fixtures/election_results.txt"

      expect(e.all?{|l| l.votes_a.is_a? Integer}).to eq(true)
    end
  end
  describe ".required" do
    class ReqTable < HashTable
      required :req
    end
    it "allows you set required columns for the class" do
      r = ReqTable.new
      expect(r.required).to eq([:req])
    end
    it "complains if the column is missing" do
      r = ReqTable.new

      expect do
        r.parse("fixtures/dogs.txt")
      end.to raise_error
    end
  end
  describe "#has_column?" do
    it "returns true for existing columns" do
      h = HashTable.new :columns => [ :one, :two, :three ]

      expect(h.has_column? :one).to eq true
    end
    it "returns false for nonexistent columns" do
      h = HashTable.new :columns => [ :one, :two, :three ]

      expect(h.has_column? :four).to eq false
    end
  end
  describe "#columns" do
    it "picks up column names from file" do
      h = HashTable.new
      h.parse "fixtures/dogs.txt"

      expect(h.columns).to eq([ :name, :breed, :owner, :created ])
    end
    it "cleans column names from file" do
      h = HashTable.new
      h.parse "fixtures/test_dirty_names.txt"

      expect(h.columns).to eq([ :name, :breed, :owner, :created ])
    end
    it "uses specified columns when parsing" do
      h = HashTable.new :columns => [ :name, :breed, :owner, :created ], :parse_mode => :noheader
      h.parse "fixtures/test_noheader.txt"

      expect(h.columns).to eq([ :name, :breed, :owner, :created ])
      expect(h.count).to eq 3
    end
    it "lets you add a column" do
      h = HashTable.new
      h.parse "fixtures/dogs.txt"
      h.has_column? :spool

      h.add_column :spool
      expect(h.first.respond_to? :spool).to be true
    end
  end
  describe "#parse" do
    it "loads from a file" do
      h = HashTable.new
      h.parse "fixtures/dogs.txt"

      expect(h.count).to eq 3
    end
  end
  describe "#output" do
    it "prints the contents" do
      h = HashTable.new
      h.parse "fixtures/dogs.txt"
      text = File.read("fixtures/dogs.txt")

      io = StringIO.new
      h.output io

      expect(io.string).to eq(text)
    end
  end
  describe "<<" do
    it "adds a new line from a hash" do
      h = HashTable.new
      h.parse "fixtures/dogs.txt"

      h << { name: "Beethoven", breed: "St. Bernard", owner: "Charles Grodin", created: 1992 }
      expect(h.count).to eq(4)
    end
  end
end

describe HashTable::Row do
  describe "#<column_name>" do
    it "allows access to named columns" do
      h = HashTable.new
      h.parse "fixtures/dogs.txt"
      r = h.first
      expect(r.respond_to? :name).to be(true)
    end
    it "forbids access to unnamed columns" do
      h = HashTable.new
      h.parse "fixtures/dogs.txt"
      r = h.first
      expect(r.respond_to? :strip).to be(false)
    end
    it "allows access to newly added columns" do
      h = HashTable.new
      h.parse "fixtures/dogs.txt"
      r = h.first
      h.columns << :strip
      expect(r.respond_to? :strip).to be(true)
    end
  end
  describe ".alias_key" do
    it "aliases a column name" do
      class DogTable < HashTable
        class Dog < HashTable::Row
          alias_key :species, :breed
        end
      end
      d = DogTable.new
      d.parse "fixtures/dogs.txt"

      r = d.first
      expect(r.respond_to? :species).to be(true)
    end
  end
end
