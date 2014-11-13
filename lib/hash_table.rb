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

    def invalidate!
      @invalid = true
    end

    def approve!
      @invalid = nil
    end

    def invalid?
      @invalid
    end

    def respond_to_missing? sym, include_all = false
      if sym.to_s =~ /^(.*)=$/
        true
      else
        @hash.has_key?(sym) || super
      end
    end

    def method_missing sym, *args, &block
      if @hash.has_key? sym
        @hash[sym]
      elsif sym.to_s =~ /(.*)=/ 
        @hash[$1.to_sym] = args.first
      else
        super
      end
    end

    def to_s
      @table.header.map do |h| 
        format_column h
      end.join("\t")
    end

    def format_column column
      if send(column).is_a?(Hash) && @table.types[column].is_a?(Array)
        send(column).map do |key,value|
          if value == true
            # just print the key
            key
          else
            "#{key}#{@table.types[column][1]}#{value}"
          end
        end.join @table.types[column][0]
      else
        send(column)
      end
    end
  end

  class << self
    attr_reader :comment
    def line_type
      @line_type || HashLine
    end

    def line_class klass
      @line_type = const_get klass.to_s.camel_case
    end

    def use_header?
      @use_header ||= false
    end
    def print_header
      @use_header = true
    end
  end
  print_header

  attr_accessor :header, :types
  def [](ind)
    if ind.is_a? Range
      wrap @lines[ind]
    else
      @lines[ind]
    end
  end

  def idx key, value=nil
    @wrapped_index[ [key, value] ] ||= get_wrapped_table key, value
  end

  def idx_keys(key)
    @bare_index[key].keys
  end

  def sum(col)
    inject(0) do |sum,line|
      sum += line[col].to_f
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

  def use_header?
    self.class.use_header?
  end

  def formatted_header
    @header.map do |h|
      @sleeve[h] || h
    end.join("\t")
  end

  def preamble
    @preamble
  end

  def output f
    f.puts preamble
    f.puts formatted_header if use_header?
    @lines.each do |l|
      l = yield l if block_given?
      next if !l || l.invalid?
      f.puts l.to_s
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

  def initialize(obj=nil,opts={})
    fix_opts(opts)
    create_header
    create_index
    @lines = []
    @preamble = []
    @sleeve = {}
    @comment = @opts[:comment] || self.class.comment

    if obj && obj.is_a?(String) && File.exists?(obj)
      parse_file obj
    elsif obj && obj.is_a?(Array)
      # it's a stack of lines. Go with it.
      @lines = obj
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
    self.class.new lines, @opts.merge( :header => @header.clone, :types => @types.clone )
  end

  def update_index key
    create_index_for key
    @lines.each do |line|
      index_line_to_key line, key
    end
  end

  protected
  def add_line hash
    if hash.is_a? HashLine
      @lines.push hash
      hash.set_table self
    else
      @lines.push create_line(hash)
    end
    index_line @lines.last
  end

  def create_header
    validate_header

    validate_types
  end

  def validate_header
    @header = @opts[:header]
    if @header.is_a? Hash
      @opts[:types] = @header
      @header = @header.keys
    end
    @skip_header = @opts[:skip_header] && @header
  end

  def enforce_header
  end

  def validate_types
    @types = @opts[:types] || {}

    raise TypeError, "Types must be a Hash!" unless @types.is_a?(Hash)

    @types.each do |key,type|
      case type
      when Array
        raise ArgumentError unless type.length == 2 && type.all?{|n| n.is_a? String}
      end
    end
  end

  def parse_file file
    load_file file

    fix_lines
  end

  def fix_lines
    @lines.each_index do |i|
      @lines[i] = create_line @lines[i]
      index_line @lines[i]
    end
  end

  def fix_opts opts
    @opts = opts
    @opts[:idx] = [ @opts[:idx] ].flatten.compact
  end

  def create_index
    @bare_index = {}
    @wrapped_index = {}
    @opts[:idx].each do |key|
      create_index_for key
    end
  end

  def create_index_for key
    @bare_index[key] ||= Hash.new do |h,k| h[k] = []; end
  end

  def create_line s
    self.class.line_type.new s, self
  end

  def index_line line
    @bare_index.each do |key,table|
      index_line_to_key line, key
    end
  end

  def index_line_to_key line, key
    if line.respond_to?(key)
      @bare_index[key][ line.send(key) ] << line
    end
  end

  def get_wrapped_table key, value
    wrap @bare_index[key][value] if @bare_index[key] && @bare_index[key][value]
  end
end
