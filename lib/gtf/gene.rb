class GTF < HashTable
  class Gene
    attr_reader :name, :strand, :transcripts, :intervals
    def initialize array
      @intervals = array
      @gene = @intervals.find{|l| l.feature == "gene"}
      @name = @gene.attribute[:gene_name]
      @strand = @gene.strand
      @transcripts = build_transcripts
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
      ints = @intervals
      if block_given?
        ints = ints.select do |i|
          yield i
        end
      end
      list = IntervalList.new ints, :type => :flat
      list.collapse!
      list.to_a
    end

    def canonical
      # find out which transcript has the longest cds
      canon = @transcripts.max_by &:canonical_transcript_score
      canon if canon.cds_size
    end

    def inspect
      "#<#{self.class.name}:#{object_id} @transcripts=#{@transcripts.count}>"
    end

    def method_missing sym, *args, &block
      @gene.send sym, *args, &block
    end
    private
    def build_transcripts
      (@intervals.select{|l| l.feature == "transcript"} || []).map do |t|
        name = t.attribute[:transcript_name]
        Transcript.new @intervals.select{|l| l.attribute[:transcript_name] == name}, name, @gtf
      end
    end
  end

  class Gene
    class Transcript
      attr_reader :name, :intervals, :introns, :transcript
      def initialize array, name, gtf
        @intervals = array
        @name = name
        @gtf = gtf

        @transcript = @intervals.find{|t| t.feature == "transcript"}
      end

      def site pos
        i = @transcript.clone :pos => pos
        intron = nil
        overlaps = @intervals.select{|f| f.contains? i }
        return cds_pos i if overlaps.find{|f| f.feature == "cds" }
        return intron_pos intron if intron = overlaps.find{|f| f.feature == "intron" }
        return utr_pos if overlaps.find{|f| f.feature =~ /UTR/ }
        { :type => :transcript }
      end

      
      def utr_pos
        { :type => :utr }
      end

      def intron_frame intron
        # find the terminal frame of the leading exon
        if strand == "+"
          (intron.prev_exon.frame + intron.prev_exon.size)%3
        else
          intron.post_exon.frame
        end
      end

      def cds_pos pos
        bases = 0
        if @strand == "+"
          cds.each do |c|
            if c.contains? pos
              bases += pos - c.start + 1
              break
            else
              bases += c.size
            end
          end
        else
          cds.reverse.each do |c|
            if c.contains? pos
              bases += c.stop - pos + 1
              break
            else
              bases += c.size
            end
          end
        end
        { :type => :cds, :pos => bases/3 }
      end

      def canonical_transcript_score
        (is_ccds? ? 100000 : 0) + cds_size
      end

      def is_ccds?
        ccds_id != nil
      end

      def cds_size
        cds.inject(0) do |sum,reg|
          sum += reg.size
        end
      end

      def cds_seq
        @cds_seq ||= get_cds_seq
      end

      def cds_pos
        @cds_pos ||= get_cds_pos
      end

      private
      def get_cds_pos
        pos = cds.map do |c|
          c.size.times.map do |i|
            GenomicLocus::Position.new c.chrom, i + c.start
          end
        end.flatten

        strand == "+" ? pos : pos.reverse
      end

      def get_cds_seq
        seq = cds.map do |c|
          c.seq ||= @gtf.fasta.locus_seq c
        end.join ''
        strand == "+" ?  seq : seq.reverse.tr('ATGC','TACG')
      end

      public
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

      def intron_pos intron
        { :type => :intron, :pos => cds_pos(intron.start-1), :frame => intron_frame(intron) }
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
          intron = e1.clone(:start => e1.stop+1, :stop => e2.start-1)
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

      def method_missing sym, *args, &block
        @transcript.send sym, *args, &block
      end

      def contains? pos
        start <= pos && stop >= pos
      end
      def transcript_start
        @transcript_start ||= @transcript.clone( :pos => (strand == "+" ? start : stop) )
      end
      def exons
        @exons ||= @intervals.select{|e| e.feature == "exon"}.sort_by &:start
      end
      def cds
        @cds ||= @intervals.select{|e| e.feature == "CDS"}.sort_by &:start
      end
      def inspect
        "#<#{self.class}:0x#{'%x' % (object_id << 1)} @name=#{@name} @intervals=#{@intervals.count}>"
      end
    end
  end
end
