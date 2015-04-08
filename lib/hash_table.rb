require 'zlib'
require 'extlib'
require 'germ/printer'
require 'hash_table_aux/hash_table_aux'
require 'hash_table/columns'
require 'hash_table/row'
require 'hash_table/index'

class HashTable
  include Enumerable
  include Printer
  include HashTable::Columns

  class << self
    def row_class
      @row_class ||= find_descendant_class HashTable::Row
    end

    def index_class
      @index_class ||= find_descendant_class HashTable::Index
    end

    def columns *columns
      default_opts[:columns] = columns
    end

    def display_names names
      default_opts[:display_names] = names
    end

    def parse_mode opt
      default_opts[:parse_mode] = opt
    end

    def print_columns opt = true
      default_opts[:print_columns] = opt
    end

    def required *columns
      default_opts[:required] = columns
    end

    def types types
      default_opts[:types] = types
    end

    def index *columns
      default_opts[:index] = columns
    end

    def default_opts
      @default_opts ||= ancestral_opts
    end
    
    def comment c
      default_opts[:comment] = c
    end

    def in_order_merge *hashes
      output = {}
      hashes.each do |hash|
        output = output.merge(hash) do |key,oldval,newval|
          if newval.is_a?(Symbol) || newval == true
            newval
          elsif oldval.is_a?(Hash) && newval.is_a?(Hash)
            oldval.dup.merge(newval)
          else
            newval.dup
          end
        end
      end
      output
    end

    private
    def find_descendant_class klass
      custom = constants.find do |c|
        dec = const_get(c)
        dec.is_a?(Class) && dec < klass
      end
      if custom
        const_get(custom)
      else
        klass
      end
    end

    def ancestral_opts
      base = {}
      anc = ancestors.find do |l|
        next if l == self
        l.respond_to? :default_opts
      end
      anc ? in_order_merge(base,anc.default_opts) : base
    end
  end

  print_columns

  attr_reader :types, :index, :columns, :display_names, :required

  def initialize(opts={})
    set_opts(opts)

    @lines = []
    @preamble = []

    create_index

    @required = @opts[:required]
    @display_names = @opts[:display_names]
    @print_columns = @opts[:print_columns]
    @comment = @opts[:comment]
    @types =  @opts[:types]
    validate_types

    @columns = @opts[:columns]
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
    f.puts header_string if @print_columns
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
    other_table.each do |line|
      add_line line
    end
    self
  end

  def wrap lines
    wrapper = self.class.new @opts.merge( columns: @columns, types: @types )
    wrapper.concat lines
  end

  def parse file
    raise IOError unless File.readable? file

    load_file file

    fix_lines

    self
  end

  private
  include HashTableAux

  def add_line hash
    if hash.is_a? self.class.row_class
      @lines.push hash
      hash.set_table self
    elsif hash.is_a? Hash
      @lines.push create_line(hash)
    else
      raise "Wrong type for add_line"
    end
    @index << @lines.last

    @lines.last
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

  def basic_opts
    { :types => {}, :columns => [], :index => [], :display_names => {},
      :required => [], :parse_mode => :orig }
  end


  def set_opts opts
    @opts = HashTable.in_order_merge(basic_opts,self.class.default_opts,opts)
  end

  def create_index
    @index ||= self.class.index_class.new self, @opts[:index]
  end


  def create_line s
    if s.is_a? self.class.row_class
      s
    else
      self.class.row_class.new s, self
    end
  end
end
