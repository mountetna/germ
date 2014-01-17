require 'oncotator'
require 'yaml'
require 'mutation_set'

class MuTect < MutationSet::Sample
  requires "contig", "position", "context", "ref_allele", "alt_allele",
    "tumor_name", "normal_name", "score", "dbsnp_site", "covered", "power",
    "tumor_power", "normal_power", "total_pairs", "improper_pairs",
    "map_q0_reads", "t_lod_fstar", "tumor_f", "contaminant_fraction",
    "contaminant_lod", "t_ref_count", "t_alt_count", "t_ref_sum", "t_alt_sum",
    "t_ref_max_mapq", "t_alt_max_mapq", "t_ins_count", "t_del_count",
    "normal_best_gt", "init_n_lod", "n_ref_count", "n_alt_count", "n_ref_sum",
    "n_alt_sum", "judgement"
  comments "##"

  class Line < MutationSet::Line
    alias_key :chrom, :contig
    alias_key :start, :position
    def stop; @stop || end_position; end
    def stop= nc; @stop = nc; end
    def keep_somatic?
      !criteria_failed?(self, [ :mutect, :somatic ])
    end
    def keep_germline?
      !criteria_failed?(self, [ :mutect, :germline ])
    end

    def end_position
      position.to_i + ref_allele.length-1
    end

    def q0_ratio
      map_q0_reads.to_f / (t_alt_count.to_i + n_alt_count.to_i)
    end
    def vf_ratio
      t_var_freq > 0 ? n_var_freq / t_var_freq : 0
    end
    def t_var_freq; t_alt_count.to_f / t_depth end
    def n_var_freq; n_alt_count.to_f / n_depth end
    def t_depth; t_alt_count.to_i + t_ref_count.to_i end
    def n_depth; n_alt_count.to_i + n_ref_count.to_i end
  end
end
