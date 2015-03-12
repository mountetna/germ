require 'zlib'
require 'extlib'
require 'germ/printer'
require 'hash_table_aux/hash_table_aux'

class HashTable
  include Enumerable
  include Printer
  include HashTableAux

  class HashLine
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
      if @table.header.has_column?(sym)
        true
      elsif trim = is_assign_symbol?(sym)
        @table.header.has_column?(trim) || super
      else
        super
      end
    end

    def method_missing sym, *args, &block
      if @table.header.has_column? sym
        @hash[sym]
      elsif (trim = is_assign_symbol?(sym)) && @table.header.has_column?(trim)
        @hash[trim] = args.first
      else
        super sym, *args, &block
      end
    end

    def to_s
      @table.header.columns.map do |h| 
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

    def format_column column
      cell = send(column)
      if cell.is_a?(Hash) && @table.header.types[column].is_a?(Array)
        cell.map do |key,value|
          if value == true
            # just print the key
            key
          else
            "#{key}#{@table.header.types[column][1]}#{value}"
          end
        end.join @table.header.types[column][0]
      else
        cell
      end
    end
  end

  class HashIndex
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
      idx.concat self.class.default_indices
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

  class HashHeader
    class << self
      def use_sleeve?
        @use_sleeve
      end

      def use_sleeve
        @use_sleeve = true
      end


      def print_header?
        @print_header ||= false
      end

      def print_header
        @print_header = true
      end

      def requires terms
        @required = terms
      end

      def might_have terms
        @optional = terms
      end

      def force_columns *args
        if args.first.is_a? Hash
          @forced_columns = args.first
        else
          @forced_columns = args
        end
      end

      def replace_columns
        @replace_columns = true
      end

      def replace_columns?
        @replace_columns
      end

      def forced_columns
        @forced_columns
      end

      def default_types
        # these are types that you use if the user does not give you one. 
        # They may be gleaned from @required and @optional
        @default_types ||= begin
          types = {}
          types.update @required if @required && @required.is_a?(Hash)
          types.update @optional if @optional && @optional.is_a?(Hash)
          types
        end
      end

      def default_columns
        # this is the header to use if user or the file do not give you one
        @required
      end
    end
    print_header

    attr_reader :columns, :types
    def initialize table, columns=nil, types=nil
      @table = table
      @preamble = []
      set_types types
      if columns
        set_columns columns
      elsif self.class.forced_columns
        set_columns self.class.forced_columns
      end
    end

    def << column_name
      add_column column_name
    end

    def to_s
      [ 
        preamble,
        formatted_header,
      ].compact.join("\n")
    end

    def output f
      f.puts to_s if self.class.print_header?
    end

    def set_columns columns
      if columns
        if columns.is_a? Hash
          set_types(columns)
          @columns = columns.keys
        else
          @columns = columns.map &:to_sym
        end
      end

      @column_set = nil

      # if so desired, use simplified symbols for easier access
      create_sleeve

      # make sure the columns are well-formed
      validate

      @columns
    end

    def set_defaults
      set_columns self.class.default_columns unless @columns
    end

    def has_column? column
      column_set.include? column
    end

    protected
    def preamble
      @preamble.empty? ? nil : @preamble.join("\n")
    end

    def formatted_header
      @columns.map do |name|
        @formatted_names[name]
      end.join("\t")
    end

    def column_set
      @column_set ||= Set.new(@columns + @columns.map(&:to_s))
    end

    def set_types types
      @types = types || self.class.default_types || {}
      if self.class.use_sleeve?
        @types = @types.map do |col,type|
          { clean_column_name(col) => type }
        end.reduce :merge
      end
    end

    def add_column col
      if self.class.use_sleeve?
        @columns << clean_column_name(col)
        @formatted_names[@columns.last] = col.to_sym
      else
        @columns << col.to_sym
        @formatted_names[@columns.last] = @columns.last
      end
      @column_set = nil
    end

    def create_sleeve 
      if self.class.use_sleeve?
        @formatted_names = Hash[clean_columns.zip @columns]
        @columns = clean_columns
      else
        @formatted_names = Hash[@columns.zip @columns]
      end
    end

    def clean_columns
      @columns.map do |name|
        clean_column_name name
      end
    end

    def clean_column_name name
      name.to_s
        .gsub(/\s+/,"_")
        .gsub(/[^\w]+/,"")
        .downcase
        .to_sym
    end

    def validate
      validate_header

      validate_types
    end

    def validate_header
      raise "Required columns are missing!" unless has_requirements?
      raise "Duplicate columns found!" if has_duplicates?
    end

    def has_requirements? 
      true
    end

    def has_duplicates?
      @columns.uniq.length != @columns.length
    end

    def validate_types
      raise TypeError, "Types must be a Hash!" unless @types.is_a?(Hash)

      @types.each do |key,type|
        case type
        when Array
          raise ArgumentError unless type.length == 2 && type.all?{|n| n.is_a? String}
        end
      end
    end
  end

  class << self
    attr_reader :comment
    def line_class
      @line_class ||= find_descendant_class HashLine
    end

    def header_class
      @header_class ||= find_descendant_class HashHeader
    end

    def index_class
      @index_class ||= find_descendant_class HashIndex
    end

    def comments c
      @comment = c
    end

    private
    def find_descendant_class klass
      custom_header = constants.find do |c|
        const_get(c) < klass
      end
      if custom_header
        const_get(custom_header)
      else
        klass
      end
    end
  end

  attr_accessor :header, :types, :index
  def initialize(obj=nil,opts={})
    fix_opts(opts)

    create_header
    create_index

    # at this point, types should be set and so should headers

    @lines = []
    @comment = @opts[:comment] || self.class.comment

    if is_file? obj
      parse_file obj
    elsif is_lines? obj
      parse_lines obj
    end

    @header.set_defaults
  end

  def is_lines? obj
    obj && obj.is_a?(Array)
  end

  def is_file? obj
    obj && obj.is_a?(String) && File.exists?(obj)
  end

  def [](ind)
    if ind.is_a? Range
      wrap @lines[ind]
    else
      @lines[ind]
    end
  end

  [ :select, :reject, :sort, :sort_by ].each do |meth|
    define_method(meth) do |&block|
      wrap @lines.send(meth, &block)
    end
  end

  def sample *args
    samp = @lines.sample *args
    if samp.is_a? Array
      wrap samp
    else
      samp
    end
  end


  def select! &block
    @lines.select! &block
    self
  end

  def sort_by! &block
    @lines.sort_by! &block
    self
  end

  def output f
    header.output f
    @lines.each do |l|
      l = yield l if block_given?
      next if !l
      f.puts l
    end
    true
  end

  def inspect
    "#<#{self.class.name}:#{object_id} @lines=#{@lines.count}>"
  end

  def each
    @lines.each do |l|
      yield l
    end
  end

  def << hash
    add_line hash
  end

  def concat other_table
    raise TypeError unless other_table.is_a? self.class
    other_table.each do |line|
      add_line line
    end
    self
  end

  def wrap lines
    self.class.new lines, @opts.merge( :header => @header.columns, :types => @header.types )
  end

  protected
  def add_line hash
    if hash.is_a? self.class.line_class
      @lines.push hash
      hash.set_table self
    elsif hash.is_a? hash
      @lines.push create_line(hash)
    else
      raise "Wrong type for hash #{hash}"
    end
    @index << @lines.last
  end

  def parse_file file
    load_file file

    fix_lines
  end
  
  def parse_lines lines
    @lines = lines

    fix_lines
  end

  def fix_lines
    @lines.each_index do |i|
      @lines[i] = create_line @lines[i]
      @index << @lines[i]
    end
  end

  def fix_opts opts
    @opts = opts
    @opts[:idx] = [ @opts[:idx] ].flatten.compact
  end

  def create_index
    @index ||= self.class.index_class.new self, @opts[:idx]
  end

  def create_line s
    if s.is_a? self.class.line_class
      s
    else
      self.class.line_class.new s, self
    end
  end

  def glean_types line
    line.map do |field|
      putative_type(field)
    end
  end

  def putative_type field
    case field
    when /^-?[0-9]+$/
      :int
    when /^-?[0-9]+\.[0-9]+$/
      :float
    else
      :str
    end
  end

  def create_header
    @header ||= self.class.header_class.new self, @opts[:header], @opts[:types]
    @skip_header = (@opts[:skip_header] || @header.class.replace_columns?) && @header.columns
  end
end
