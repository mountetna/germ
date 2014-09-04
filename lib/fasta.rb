#!/usr/bin/env ruby
require 'fasta_aux/fasta_aux'
require 'germ/config'
require 'genomic_locus'

class Fasta
  private
  include FastaAux
  extend GermDefault

  class << self
    def guess_line_size file
      io = File.open file

      # Grab the first 50 lines
      lines = 50.times.map do io.gets end.compact

      chroms = lines.each_index.map.select do |i| lines[i] =~ /^>/ end

      chroms.each_index do |i|
        chrom_lines = lines[ chroms[i] + 1 ... chroms[i+1] || lines.size ]
        # you need at least 2 lines to be sure.
        next if chrom_lines.size < 2
        return chrom_lines.first.chomp.size if chrom_lines[0].size == chrom_lines[1].size
      end

      # You can't guess, raise an exception.
      raise "Could not guess file line size, please specify"
    end
  end

  class Chrom
    include GenomicLocus
    attr_reader :seqname, :size, :start
    alias_method :chrom, :seqname
    alias_method :pos, :start
    alias_method :stop, :size
    def initialize n, fasta, sz, st
      @seqname, @fasta, @size, @byte_start = n, fasta, sz, st
      # truncate the name
      @seqname = short_chrom
      @start = 1
    end

    def file_pos pos
      return nil if !contains? pos
      @byte_start + pos/line_size*(line_size+1) + (pos % line_size) - 1 - ((pos % line_size == 0) ? 1 : 0)
    end

    private
    def line_size
      @fasta.line_size
    end
  end

  def seq_size_from_byte_size bytes
    (bytes/(@line_size+1))*@line_size + (bytes % (@line_size+1))
  end

  def compute_chrom_stats
    @chroms = {}
    @seq_names.each_with_index do |name, i|
      if i < @seq_names.size-1
        size = seq_size_from_byte_size(@seq_starts[i+1] - @seq_starts[i] - @seq_names[i+1].size - 3)
      else
        size = seq_size_from_byte_size(@io.size - @seq_starts[i])
      end
      @chroms[name] = Fasta::Chrom.new name, self, size, @seq_starts[i]
      # just save it as both
      @chroms[ @chroms[name].short_chrom ] = @chroms[name]
    end
  end

  public
  attr_reader :line_size, :chroms
  def initialize file, size=nil
    @io = File.open(file)

    @line_size = size || Fasta.guess_line_size(file)

    get_seq_starts

    compute_chrom_stats
  end

  def size
    @chroms.inject(0) { |s,v| s += v.last.size }
  end

  def inspect
    "#<#{self.class.name}:#{object_id} @chroms=#{@seq_names.count}>"
  end

  def locus_seq locus
    raise TypeError, "not a GenomicLocus!" unless locus.is_a? GenomicLocus
    get_seq locus.short_chrom, locus.start, locus.stop
  end

  def get_seq chrom, start, stop
    seq = get_masked_seq chrom, start, stop
    seq && seq.upcase
  end

  def interval_missing?(locus)
    !@chroms[locus.seqname] || !@chroms[locus.seqname].contains?(locus)
  end

  def get_masked_seq chrom, start, stop
    raise ArgumentError, "Improper interval #{chrom}:#{start}-#{stop}" if interval_missing?(GenomicLocus::Region.new(chrom,start,stop))

    get_seq_chunk(@chroms[chrom].file_pos(start), @chroms[chrom].file_pos(stop)).gsub(/\n/,'')
  end
end
