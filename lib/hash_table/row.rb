class HashTable
  class Row
    def self.alias_key sym1, sym2
      define_method sym1 do
        send sym2
      end
      define_method "#{sym1}=" do |v|
        send "#{sym2}=", v
      end
    end

    def initialize h, table
      @hash = Hash[h]
      @table = table
    end

    def update hash
      @hash.update hash
    end

    def set_table t
      @table = t
    end

    def [] ind
      @hash[ind]
    end

    def []= ind,v
      @hash[ind] = v
    end

    def to_a
      @hash.values
    end

    def to_hash
      @hash.clone
    end

    def respond_to_missing? sym, include_all = false
      if @table.has_column?(sym)
        true
      elsif trim = is_assign_symbol?(sym)
        @table.has_column?(trim) || super
      else
        super
      end
    end

    def method_missing sym, *args, &block
      if @table.has_column? sym
        @hash[sym]
      elsif (trim = is_assign_symbol?(sym)) && @table.has_column?(trim)
        @hash[trim] = args.first
      else
        super sym, *args, &block
      end
    end

    def to_s
      @table.columns.map do |h| 
        format_column h
      end.join("\t")
    end

    private
    ASSIGN = /^(.*)=$/
    def is_assign_symbol? s
      s.to_s.match(ASSIGN) do |m|
        return m[1].to_sym
      end
    end

    def default_copy
      self.class.new @hash.clone, @table
    end

    def format_column column
      cell = send(column)
      if cell.is_a?(Hash) && @table.types[column].is_a?(Array)
        join_hash(column,cell)
      elsif cell.is_a?(Array) && @table.types[column].is_a?(Array)
        join_array(column,cell)
      else
        cell
      end
    end

    def join_array(column, cell)
      cell.join(@table.types[column][0])
    end

    def join_hash column, cell
      cell.map do |key,value|
        if value == true
          key
        else
          "#{key}#{@table.types[column][1]}#{value}"
        end
      end.join @table.types[column][0]
    end
  end
end
