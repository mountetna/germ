require 'hash_table'

describe HashTable::HashLine do
  describe "#<accessor>" do
    it "retrieves keys that are defined in the table header" do
      table = HashTable.new "support/files/table1.txt"

      line = table.first

      expect(line.species).to eq "dog"
    end

    it "raises if key is not defined in the table header" do
      table = HashTable.new "support/files/table1.txt"

      line = table.first

      expect { line.spoocies }.to raise_error(NoMethodError)
    end

    it "allows setting of keys defined in the table header" do
      table = HashTable.new "support/files/table1.txt"
      table.header << :new_column
      line = table.first

      line.new_column = "new entry"

      expect(line.new_column).to eq "new entry"
    end

    it "raises on setting of keys not in the table header" do
      table = HashTable.new "support/files/table1.txt"
      line = table.first

      expect { line.new_column = "new entry" }.to raise_error(NoMethodError)
    end
  end
end

describe HashTable::HashHeader do
  context "loading from file" do
    context "class specifies header" do
      it "uses class's header" do
        class TestTable < HashTable
          class TestHeader < HashTable::HashHeader
            force_columns :species, :name, :age, :drink, :rating
          end
          header_class TestHeader
        end
        table = TestTable.new "support/files/table1.txt"

        columns = table.header.columns

        expect(columns).to eq TestTable::TestHeader.forced_columns
      end
    end

    context "user specifies header" do
      it "uses user's header" do
        my_header = [ :species, :name, :age, :drink, :rating ]
        table = HashTable.new "support/files/table1.txt", :header => my_header

        columns = table.header.columns

        expect(columns).to eq my_header
      end
    end

    context "no header specified" do
      it "uses file's header" do
        file_header = [ :species, :name, :age, :beverage, :rating ]
        table = HashTable.new "support/files/table1.txt"

        columns = table.header.columns

        expect(columns).to eq file_header
      end
    end
  end

  context "loading from array" do
    it "complains without a header" do
      expect { HashTable.new [] }.to raise_error
    end

    it "loads with a header" do
      expect { HashTable.new [], :header => [ :a, :b, :c ] }.not_to raise_error
    end
  end

  context "copying existing table" do
  end
end

describe HashTable do
  describe "#select" do
    it "yields another hash_table" do
      table = HashTable.new "support/files/table1.txt"

      table2 = table.select{|l| l.species == "dog"}

      expect(table2.is_a? HashTable).to be true
    end
  end

  describe "#print" do
    it "prints to a file" do
      table = HashTable.new "support/files/table1.txt"
    end
  end
end

