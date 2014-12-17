require 'hash_table'
require 'intervals'
require 'genomic_locus'
require 'genetic_code'
require 'gtf/gene'
require 'fasta'
require 'germ/config'

class GTF < HashTable
  extend GermDefault
  include IntervalList

  def self.default_create file, idx=nil
    if idx
      new file, :idx => idx
    else
      new file
    end
  end

  class Header < HashTable::HashHeader
  end
  header_class Header
  class Feature < HashTable::HashLine
    include GenomicLocus
    def copy
      self.class.new @hash.clone, @table
    end

    def seq
      @seq ||= @table.fasta.locus_seq self
    end

    def respond_to_missing? sym, include_all = false
      self[:attribute].has_key?(sym) || super
    end

    def method_missing sym, *args, &block
      if self[:attribute].has_key?(sym)
        self[:attribute][sym]
      else
        super
      end
    end
  end
  line_class GTF::Feature

  def initialize file, opts=nil
    opts = { :comment => "#", :sep => " "}.merge(opts || {})

    @sep = opts[:sep]

    @genes = {}

    super file, :comment => opts[:comment], :idx => opts[:idx],
      :header => [ :seqname, :source, :feature, :start, :stop, :score, :strand, :frame, :attribute ],
      :types => { :start => :int, :stop => :int, :score => :int, :frame =>
                  :int, :attribute => [ ";", @sep ] }
  end

  def inspect
    "#<#{self.class}:0x#{'%x' % (object_id << 1)} @lines=#{@lines.count}>"
  end

  def fasta
    @opts[:fasta] || Fasta.default
  end

  def add_line hash
    add_interval(super)
  end

  protected
  def add_index line
    @index.each do |key,ind|
      ikey = line[key] || line[:attribute][key]
      next if !ikey
      (ind[ ikey ] ||= []) << line
    end
  end
end
