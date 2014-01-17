require 'oncotator'
require 'yaml'
require 'mutation_set'

class Indelocator < MutationSet::Sample
  comments "##"

  requires "chrom", "start", "stop", "change", 
    "n_obs_counts", "n_av_mm", "n_av_mapq", "n_nqs_mm_rate", "n_nqs_av_qual", "n_strand_counts",
    "t_obs_counts", "t_av_mm", "t_av_mapq", "t_nqs_mm_rate", "t_nqs_av_qual", "t_strand_counts",
    "status"

  class Line < MutationSet::Line
    def keep_somatic?
      !criteria_failed?(self, [ :mutect, :somatic ])
    end
    def keep_germline?
      !criteria_failed?(self, [ :mutect, :germline ])
    end

    def to_ot
      "#{contig.sub(/chr/,"")}_#{position}_#{position.to_i + ref_allele.length-1}_#{ref_allele}_#{alt_allele}"
    end

    def t_var_freq; t_alt_count.to_f / t_depth end
    def n_var_freq; n_alt_count.to_f / n_depth end
    def t_depth; t_alt_count.to_i + t_ref_count.to_i end
    def n_depth; n_alt_count.to_i + n_ref_count.to_i end

    def initialize fields, sample
      @sample = sample

      @mutation = Hash[sample.clean_headers.zip(fields)]

      @mutation.each do |key,value|
        next if key.to_s !~ /^[nt]_/
        @mutation[key] = value.scan(/:(.*)/).flatten.first.split %r!/!
      end
    end
  end

  def initialize mutation_config=nil, suppress_headers=nil
    super mutation_config, suppress_headers
    @headers = required.map(&:to_sym)
  end
end
