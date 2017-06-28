require 'filter'
require 'hash_table'

describe Filter do
  describe "#passes?" do
    context "min_ filter" do
      it "rejects if the value is below the criterion" do
        f = Filter.new min_created: 1954
        h = HashTable.new
        h.parse fixture(:dogs)

        count = h.count{|l| f.passes? l}

        expect(count).to be(2)
      end
    end
    context "max_ filter" do
      it "rejects if the value is above the criterion" do
        f = Filter.new max_created: 1945

        h = HashTable.new
        h.parse fixture(:dogs)

        expect(h.count{|l| f.passes?(l)}).to be(0)
      end
    end
    context "exclude_ filter" do
      it "excludes symbols matching the given pattern" do
        f = Filter.new exclude_name: "Snoopy"

        h = HashTable.new
        h.parse fixture(:dogs)

        expect(h.count{|l| f.passes?(l)}).to be(2)
      end
      it "excludes symbols matching the given patterns" do
        f = Filter.new exclude_name: [ "Snoopy", "Marmaduke" ]

        h = HashTable.new
        h.parse fixture(:dogs)

        expect(h.count{|l| f.passes?(l)}).to be(1)
      end
    end
    context "has_ filter" do
      it "requires the given symbols to match" do
        f = Filter.new has_name: "Snoopy"

        h = HashTable.new
        h.parse fixture(:dogs)

        expect(h.count{|l| f.passes?(l)}).to be(1)
      end
      it "requires one of the given symbols to match" do
        f = Filter.new has_name: [ "Snoopy", "Marmaduke" ]

        h = HashTable.new
        h.parse fixture(:dogs)

        expect(h.count{|l| f.passes?(l)}).to be(2)
      end
      it "requires the given symbol to be present and non-empty" do
        f = Filter.new has_breed: true

        h = HashTable.new
        h.parse fixture(:dogs)

        expect(h.count{|l| f.passes?(l)}).to be(2)
      end
      it "requires the given symbol to be empty" do
        f = Filter.new has_breed: false

        h = HashTable.new
        h.parse fixture(:dogs)

        expect(h.count{|l| f.passes?(l)}).to be(1)
      end
    end
  end
end
