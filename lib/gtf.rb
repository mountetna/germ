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

  def self.default_create file, opts
    new(opts).parse(file)
  end

  columns :seqname, :source, :feature, :start, :stop, :score, :strand, :frame, :attribute
  types start: :int, stop: :int, score: :int, frame: :int, attribute: [ ";", " " ]
  print_columns false
  parse_mode :noheader
  comment "#"

  class Feature < HashTable::Row
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

    def join_hash column, cell
      tag_sep, pair_sep = @table.types[column]

      tag_sep = tag_sep + " " if column == :attribute

      cell.map do |key,value|
        format_tag key, value, pair_sep
      end.join tag_sep
    end

    def format_tag key, value, sep
      if value == true
        key
      else
        %Q(#{key}#{sep}"#{value}")
      end
    end
  end

  def initialize opts = {}
    super opts

    @genes = {}
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
