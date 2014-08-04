require 'zlib'
require 'extlib'
require 'germ/printer'
require 'hash_table_aux/hash_table_aux'

class HashTable
  include Enumerable
  include Printer
  include HashTableAux

  class HashLine
    def initialize h, table
      @hash = Hash[h]
      @table = table
    end

    def update hash
      @hash.update hash
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

    def method_missing sym, *args, &block
      if @hash[sym]
        @hash[sym]
      elsif sym.to_s =~ /(.*)=/ 
        @hash[$1.to_sym] = args.first
      else
        nil
      end
    end
  end

  class << self
    def line_type
      @line_type || HashLine
    end

    def line_class klass
      @line_type = const_get klass.to_s.camel_case
    end

    def use_header?
      @use_header
    end
    def header_on
      @use_header = true
    end
    def header_off
      @use_header = nil
    end
  end
  header_on

  attr_accessor :header
  def [](ind)
    @lines[ind]
  end

  def method_missing sym, *args, &block
    if @index[sym]
      @index[sym]
    else
      super sym, *args, &block
    end
  end

  def sum(col)
    inject(0) do |sum,line|
      sum += line[col].to_f
    end
  end

  def select! &block
    @lines.select! &block
  end

  def sort_by! &block
    @lines.sort_by! &block
  end

  def use_header?
    self.class.use_header?
  end

  def output f
    f.puts @header.join("\t") if use_header?
    @lines.each do |l|
      l = yield l if block_given?
      next if !l || l.invalid?
      f.puts format_line(l)
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

  def initialize(file,opts={})
    @opts = opts
    create_header
    create_index
    @lines = []
    @comment = @opts[:comment]

    parse_file(file) if file && File.exists?(file)
  end

  def add_line hash
    if hash.is_a? HashLine
      @lines.push hash
    else
      @lines.push create_line(hash)
    end
  end

  private
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
    @skip_header = @opts[:skip_header] && @opts[:header]
  end

  def validate_types
    @types ||= @opts[:types]

    raise TypeError, "Types must be a Hash!" unless !@types || @types.is_a?(Hash)

    return if !@types

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
      add_index @lines[i] unless @index.empty?
    end
  end

  def create_index
    idx = @opts[:idx]
    if !idx
      @index = {}
      return
    end
    idx = [ idx ] if !idx.is_a? Array
    @index = Hash[idx.map{|i| [ i, {} ] }]
  end

  def format_line l
    @header.map{|h| l[h]}.join("\t")
  end

  def line_hash s
    @header.zip(s.split(/\t/))
  end

  def is_comment? s
    @comment && s =~ @comment
  end

  protected
  def create_line s
    self.class.line_type.new s, self
  end

  def add_index line
    @index.each do |key,ind|
      next if !line[key]
      (ind[ line[key] ] ||= []) << line
    end
  end
end
