require 'hash_table'
require 'intervals'
require 'genomic_locus'
require 'genetic_code'
require 'gtf/gene'
require 'fasta'

class GTF < HashTable
  header_off

  class GTFLine < HashTable::HashLine
    include GenomicLocus
    def chrom; seqname; end
    def chrom= nc; seqname = nc; end
    def copy
      c = self.class.new @hash.clone
    end

    def method_missing sym, *args, &block
      self[:attribute][sym] || super(sym, *args, &block)
    end
  end
  line_class GTFLine


  def gene name
    intervals = gene_name[name]
    @genes[name] ||= GTF::Gene.new intervals if intervals
  end

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

  def to_interval_list
    IntervalList.new self
  end

  def format_line g
    [ :seqname, :source, :feature, :start, :stop, :score, :strand, :frame, :attribute ].map do |h|
      if h == :attribute
        g[:attribute].map do |k,v| 
          "#{k}#{@sep}#{v}" 
        end.join("; ")
      else
        g[h]
      end
    end.join("\t")
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
