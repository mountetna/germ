class HashTable
  class Index
    class ColumnIndex
      def initialize table, column
        @table = table
        @key = column

        @index = Hash.new do |h,k|
          h[k] = Set.new()
        end
        @wrapped = {}
      end

      def << line
        index_line line if line.respond_to? @key
      end

      def [] value
        @wrapped[value] ||= @table.wrap @index[value].to_a
      end

      def entries
        @index.keys
      end

      def inspect
        "#<#{self.class.name}:#{object_id} @index=#{@index.size}>"
      end

      private
      def index_line line
        value = line.send @key
        if value
          @index[value] << line
          @wrapped[value] = nil
        end
      end
    end

    class << self
      def always_index *idxs
        @default_indices = idxs
      end

      def default_indices
        @default_indices ||= []
      end
    end

    def initialize table, idx
      @table = table
      @columns = {}
      idx ||= []
      idx.each do |column|
        create_column_index column
      end
    end

    def [] column
      @columns[column]
    end

    def << line
      index_line line
    end

    def index_column column
      create_column_index column
      @table.each do |line|
        @columns[column] << line
      end
    end

    protected
    def index_line line
      @columns.each do |column,column_index|
        column_index << line
      end
    end

    def create_column_index column
      @columns[column] ||= ColumnIndex.new @table, column
    end
  end
end
