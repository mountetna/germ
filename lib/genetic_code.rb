#!/usr/bin/env ruby

class GeneticCode
  MAP = {
    :alanine => [ :GCT, :GCC, :GCA, :GCG ],
    :leucine => [ :TTA, :TTG, :CTT, :CTC, :CTA, :CTG ],
    :arginine => [ :CGT, :CGC, :CGA, :CGG, :AGA, :AGG ],
    :lysine => [ :AAA, :AAG ],
    :asparagine => [ :AAT, :AAC ],
    :methionine => [ :ATG ],
    :aspartic_acid => [ :GAT, :GAC ],
    :phenylalinine => [ :TTT, :TTC ],
    :cysteine => [ :TGT, :TGC ],
    :proline => [ :CCT, :CCC, :CCA, :CCG ],
    :glutamine => [ :CAA, :CAG ],
    :serine => [ :TCT, :TCC, :TCA, :TCG, :AGT, :AGC ],
    :glutamic_acid => [ :GAA, :GAG ],
    :threonine => [ :ACT, :ACC, :ACA, :ACG ],
    :gylcine => [ :GGT, :GGC, :GGA, :GGG ],
    :tryptophan => [ :TGG ],
    :histidine => [ :CAT, :CAC ],
    :tyrosine => [ :TAT, :TAC ],
    :isoleucine => [ :ATT, :ATC, :ATA ],
    :valine => [ :GTT, :GTC, :GTA, :GTG ],
    :stop => [ :TAA, :TGA, :TAG ]
  }
  class << self
    def codons_for aa
      MAP[aa]
    end

    def aa_for codon
      aa = MAP.keys.find do |aa|
        MAP[aa].include? codon
      end
      AminoAcid[aa] if aa
    end
  end
end

class AminoAcid
  BASE = {
    :alanine => { :letter => :A, :short => :Ala },
    :leucine => { :letter => :L, :short => :Leu },
    :arginine => { :letter => :R, :short => :Arg },
    :lysine => { :letter => :K, :short => :Lys },
    :asparagine => { :letter => :N, :short => :Asn },
    :methionine => { :letter => :M, :short => :Met },
    :aspartic_acid => { :letter => :D, :short => :Asp },
    :phenylalinine => { :letter => :F, :short => :Phe },
    :cysteine => { :letter => :C, :short => :Cys },
    :proline => { :letter => :P, :short => :Pro },
    :glutamine => { :letter => :Q, :short => :Gln },
    :serine => { :letter => :S, :short => :Ser },
    :glutamic_acid => { :letter => :E, :short => :Glu },
    :threonine => { :letter => :T, :short => :Thr },
    :gylcine => { :letter => :G, :short => :Gly },
    :tryptophan => { :letter => :W, :short => :Trp },
    :histidine => { :letter => :H, :short => :His },
    :tyrosine => { :letter => :Y, :short => :Tyr },
    :isoleucine => { :letter => :I, :short => :Ile },
    :valine => { :letter => :V, :short => :Val },
    :stop => { :letter => :*, :short => :Stop }
  }
  class << self
    def [] aa_name
      @aa ||= {}
      @aa[aa_name] ||= build_aa aa_name
    end

    def build_aa aa_name
      new aa_name
    end
  end

  attr_reader :letter, :short, :codons, :name
  def initialize aa_name
    raise ArgumentError, "No such amino acid." unless BASE[aa_name]
    aa_info = BASE[aa_name]
    @name = aa_name
    @letter = aa_info[:letter]
    @short = aa_info[:short]
    @codons = aa_info[:codons]
  end
end

class Codon
  class << self
    def [] seq
      @codons ||= {}
      @codons[seq] ||= build_codon seq
    end

    def build_codon seq
      return nil unless seq.is_a?(Symbol) && seq.to_s =~ /^[ATGC]{3}$/
      new seq
    end
  end

  attr_reader :seq, :aliases, :aa
  def initialize seq
    @seq = seq
    @aa = GeneticCode.aa_for seq
    @aliases = @aa.codons
  end

  def degeneracy
    @degeneracy ||= compute_degeneracy
  end

  def distance_to codon
    s1 = seq.to_s
    s2 = codon.seq.to_s
    3.times.count do |i|
      s1[i] != s2[i]
    end
  end

  def compute_degeneracy
    3.times.map do |i|
      [ "A", "T", "G", "C" ].count do |n|
        mut = seq.to_s
        mut[i] = n
        @aliases.include? mut.to_sym
      end
    end
  end
end

class TriNuc
  attr_reader :codon, :pos, :seq, :index, :strand
  def initialize seq, pos, strand, ind=nil
    raise ArgumentError, "Sequence is malformed" unless seq && seq =~ /^[ATGC]{3}$/
    raise ArgumentError, "Three genomic coordinates are required" unless pos.is_a?(Array) && pos.length == 3
    @seq = seq.to_sym
    @pos = pos
    @strand = strand
    @index = ind
    @codon = Codon[@seq]
  end
end
