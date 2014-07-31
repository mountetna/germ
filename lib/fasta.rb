#!/usr/bin/env ruby
require 'fasta_aux/fasta_aux'
require 'germ/config'

class Fasta
  private
  include FastaAux

  class << self
    GENOMES = {}
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

    def default
      sym = genome_file :default_genome
      file = genome_file sym
      load_genome sym, file if file && File.exists?(file)
    end

    def load_genome sym, file
      GENOMES[sym] ||= Fasta.new file, genome_linesize(sym)
    end

    def method_missing sym, *args, &block
      file = genome_file(sym)
      return load_genome sym, file if file && file.is_a?(String) && File.exists?(file)
      super sym, *args, &block
    end

    private
    def genome_file sym
      record = GermConfig.get_conf :fasta, sym
      if record.is_a? Hash
        record[:file] or raise "Config record is not well-formed, expected :file"
      else
        record
      end
    end

    def genome_linesize sym
      record = GermConfig.get_conf :fasta, sym
      if record.is_a? Hash
        record[:linesize] or raise "Config record is not well-formed, expected :linesize"
      end
    end
  end

  class Chrom
    include GenomicLocus
    attr_reader :name, :size
    def start 1; end
    alias_method :chrom, :name
    alias_method :pos, :start
    alias_method :stop, :size
    def initialize n, fasta, sz, st
      @name, @fasta, @size, @byte_start = n, fasta, sz, st
    end

    def file_pos pos
      return nil if !contains? pos
      byte_start + pos/line_size*(line_size+1) + (pos % line_size) - 1 - ((pos % line_size == 0) ? 1 : 0)
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

  def interval_missing?(chrom,start,stop)
    !@chroms[chrom] || !@chroms[chrom].contains?([start,stop])
  end

  def get_masked_seq chrom, start, stop
    raise ArgumentError, "Improper interval #{chrom}:#{start}-#{stop}" if interval_missing?(chrom,start,stop)

    get_seq_chunk(@chroms[chrom].file_pos(start), @chroms[chrom].file_pos(stop)).gsub(/\n/,'')
  end
end
