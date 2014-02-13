require 'zlib'
require 'extlib'
require 'taylorlib/printer'
require 'hash_table_aux/hash_table_aux'

class HashTable
  include Enumerable
  include Printer
  include HashTableAux

  class HashLine
    def initialize h
      if h.is_a? Array
        @hash = Hash[h]
      elsif h.is_a? Hash
        @hash = h
      end
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
    @header = opts[:header]
    if @header.is_a? Hash
      @types = @header.values
      @header = @header.keys
    end
    create_index opts[:idx]
    @lines = []
    @comment = opts[:comment]
    @types ||= opts[:types]

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
  def parse_file file
    load_file file
    @lines.each_index do |i|
      @lines[i] = create_line @lines[i]
      add_index @lines[i] unless @index.empty?
    end
  end

  def create_index idx
    if !idx
      @index = {}
      return
    end
    idx = [ idx ] if !idx.is_a? Array
    @index = Hash[idx.map{|i| [ i, {} ] }]
  end

  def set_header s, downcase=nil
    return nil if @header
    @header = s.chomp.split(/\t/).map{|s| downcase ? s.downcase.to_sym : s.to_sym }
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
    self.class.line_type.new s
  end

  def add_index line
    @index.each do |key,ind|
      next if !line[key]
      (ind[ line[key] ] ||= []) << line
    end
  end
end
