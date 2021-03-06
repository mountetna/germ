class GTF < HashTable
  def gene name
    intervals = index[:gene_name][name]
    @genes[name] ||= GTF::Gene.new intervals if intervals
  end

  def promoters
    @promoters ||= begin
      promoters = []
      index[:gene_name].entries.each do |name|
        promoters.concat gene(name).transcripts.map(&:transcript_start)
      end
      wrap promoters
    end
  end

  class Gene
    include Enumerable
    include IntervalList
    attr_reader :name, :strand, :transcripts, :intervals
    def initialize intervals
      @intervals = intervals.sort_by &:start
      @gene = @intervals.find{|l| l.feature == "gene"}
      @name = @gene.attribute[:gene_name]
      @strand = @gene.strand
      @transcripts = build_transcripts
    end

    def each
      @intervals.each do |int|
        yield int
      end
    end

    def site pos
      score = { :cds => 1, :exon => 2, :utr => 3, :intron => 4, :transcript => 5, :igr => 6 }
      sites = @transcripts.map do |t|
        { :gene => name }.update(t.site pos) if t.contains? pos
      end.compact
      sites.push(:type => :igr)
      sites.sort_by{|s| score[s[:type]] }.first
    end

    # compute unified intervals from the list of intervals
    def unified
      @unified ||= exons.flatten do |unif|
        unif.feature = "unified"
      end
    end

    def exons
      @exons ||= @intervals.select{|e| e.feature == "exon"}
    end

    def canonical
      # find out which transcript has the longest cds
      canon = @transcripts.max_by &:canonical_transcript_score
      canon if canon.cds_size
    end

    def inspect
      "#<#{self.class.name}:#{object_id} @transcripts=#{@transcripts.count}>"
    end

    def respond_to_missing? sym, include_all = false
      @gene.respond_to?(sym) || super
    end

    def method_missing sym, *args, &block
      @gene.send sym, *args, &block
    end

    private
    def build_transcripts
      (@intervals.select{|l| l.feature == "transcript"}).map do |t|
        name = t.transcript_name
        transcript_ints = @intervals.select do |l|
          l.attribute[:transcript_name] == name && l.seqname == t.seqname
        end
        GTF::Transcript.new(transcript_ints, name, @gtf)
      end
    end
  end

  class Transcript
    attr_reader :name, :intervals, :introns, :transcript
    def initialize array, name, gtf
      @intervals = array
      @name = name
      @gtf = gtf

      @transcript = @intervals.find{|t| t.feature == "transcript"}
    end

    def canonical_transcript_score
      (is_ccds? ? 100000 : 0) + cds_size
    end

    def is_ccds?
      respond_to?(:ccds_id) && ccds_id != nil
    end

    def cds_size
      cds.inject(0) do |sum,reg|
        sum += reg.size
      end
    end

    def cds_seq
      @cds_seq ||= begin
        seq = cds.map(&:seq).join ''
        strand == "+" ?  seq : seq.reverse.tr('ATGC','TACG')
      end
    end

    def cds_pos
      @cds_pos ||=
        begin
          pos = cds.map do |c|
            c.size.times.map do |i|
              GenomicLocus::Position.new c.seqname, i + c.start
            end
          end.flatten

          strand == "+" ? pos : pos.reverse
        end
    end

    def exon_seq
      @exon_seq ||= begin
        seq = exons.map(&:seq).join ''
        strand == "+" ?  seq : seq.reverse.tr('ATGC','TACG')
      end
    end

    def exon_pos
      @exon_pos ||= 
        begin
          pos = exons.map do |c|
            c.size.times.map do |i|
              GenomicLocus::Position.new c.seqname, i + c.start
            end
          end.flatten

          strand == "+" ? pos : pos.reverse
        end
    end

    def translation_start_pos
      @translation_start_pos ||= GenomicLocus::Position.new @transcript.seqname, (strand == "+" ?  cds.first.start : cds.last.stop)
    end

    def translation_stop_pos
      @translation_stop_pos ||= GenomicLocus::Position.new @transcript.seqname, (strand == "+" ? cds.last.stop : cds.first.start)
    end

    def protein_seq
      trinucs.map do |t|
        t.codon.aa.letter
      end.join ''
    end

    def protein_seq_at locus
      trinucs.map do |t|
        # Just include it if it overlaps the locus
        t.codon.aa.letter if t.pos.any? {|p| p.overlaps? locus}
      end.compact.join ''
    end

    def protein_change mutation
      # replace the positions that overlap the mutation
      tnucs = trinucs.select do |tn|
        tn.pos.any? do |p|
          p.overlaps? mutation
        end
      end
      return nil if tnucs.empty?
      muts = tnucs.map do |tn|
        seq = tn.seq.to_s
        3.times do |i|
          next unless mutation.overlaps? tn.pos[i]
          seq[i] = mutation.alt_at(tn.pos[i])
          seq[i] = seq[i].tr('ATGC', 'TACG') if strand == "-"
        end
        TriNuc.new seq, tn.pos, strand
      end
      pre = tnucs.map do |tn|
        tn.codon.aa.letter
      end.join ''
      post = muts.map do |tn|
        tn.codon.aa.letter
      end.join ''
      "#{pre}#{tnucs.first.index+1}#{post}"
    end

    def trinucs
      @trinucs ||= trinucs_for cds_seq, cds_pos
    end

    def trinucs_for cds_seq, cds_pos
      aa_count = cds_seq.size / 3
      aa_count.times.map do |i|
        range = 3 * i .. 3*i + 2
        TriNuc.new cds_seq[range], cds_pos[range], strand, i
      end
    end

    def utr3
      return @utr3 if @utr3
      cs = strand == "+" ? cds.first : cds.last
      @utr3 = exons.select{ |e| strand == "+" ? !e.above?(cs) : !e.below?(cs) }
        .map{|e| e.strict_diff(cs) }
        .compact.map(&:to_a)
      @utr3.each do |u|
        u.feature = "3' UTR"
      end
    end

    def utr5
      return @utr5 if @utr5
      cs = strand == "+" ? cds.last : cds.first
      @utr5 = exons.select{|e| strand == "+" ? !e.below?(cs) : !e.above?(cs) }
        .map{|e| e.strict_diff(cs)}
        .compact.map(&:to_a)
      @utr5.each do |u|
        u.feature = "5' UTR"
      end
    end

    def build_introns
      return if !exons
      @introns = exons.map.with_index do |e1,i|
        e2 = @exons[i+1]
        next if !e2
        intron = e1.clone do |c|
          c.start = e1.stop+1
          c.stop = e2.start-1
        end
        intron.feature = "intron"
        intron.prev_exon = e1
        intron.post_exon = e2
        intron
      end.compact
      @intervals.concat @introns
    end

    def build_utrs
      @intervals.concat @utr3 if @utr3
      @intervals.concat @utr5 if @utr5
    end

    def respond_to_missing? sym, include_all=false
      @transcript.respond_to?(sym) || super
    end

    def method_missing sym, *args, &block
      @transcript.send(sym, *args, &block)
    end

    def contains? pos
      start <= pos && stop >= pos
    end
    def transcript_start
      @transcript_start ||= @transcript.clone do |c|
        c.start = c.stop = (strand == "+" ? start : stop)
        c.feature = "transcript_start"
      end
    end
    def exons
      @exons ||= @intervals.select{|e| e.feature == "exon"}
    end
    def cds
      @cds ||= @intervals.select{|e| e.feature == "CDS"}
    end
    def inspect
      "#<#{self.class}:0x#{'%x' % (object_id << 1)} @name=#{@name} @intervals=#{@intervals.count}>"
    end
    # output this transcript in the odious 'refFlat' format, demanded by Picard and others
    def to_refflat
      [ gene_name, name, seqname, strand, start, stop, cds.map(&:start).min, cds.map(&:stop).max, exons.count,
        exons.map(&:start).sort.join(','),
        exons.map(&:stop).sort.join(',')
      ].join "\t"
    end
  end
end
