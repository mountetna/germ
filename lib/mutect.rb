require 'oncotator'
require 'yaml'
require 'mutation_set'

class MuTect < Mutation::Collection
  print_header
  requires :contig => :str, :position => :int, :context => :str, :ref_allele => :str, :alt_allele => :str,
    :tumor_name => :str, :normal_name => :str, :score => :float, :dbsnp_site => :str, :covered => :str, :power => :float,
    :tumor_power => :float, :normal_power => :float, :total_pairs => :int, :improper_pairs => :int,
    :map_q0_reads => :int, :t_lod_fstar => :float, :tumor_f => :float, :contaminant_fraction => :float,
    :contaminant_lod => :float, :t_ref_count => :int, :t_alt_count => :int, :t_ref_sum => :int, :t_alt_sum => :int,
    :t_ref_max_mapq => :int, :t_alt_max_mapq => :int, :t_ins_count => :int, :t_del_count => :int,
    :normal_best_gt => :str, :init_n_lod => :float, :n_ref_count => :int, :n_alt_count => :int, :n_ref_sum => :int,
    :n_alt_sum => :int, :judgement => :str
  comments "##"

  class Line < Mutation::Record
    alias_key :seqname, :contig
    alias_key :pos, :position
    alias_key :start, :position
    alias_key :stop, :default_stop
    alias_key :ref, :ref_allele
    alias_key :alt, :alt_allele
    def keep_somatic?
      !criteria_failed?(self, [ :mutect, :somatic ])
    end
    def keep_germline?
      !criteria_failed?(self, [ :mutect, :germline ])
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

    def initialize h, table
      super h, table
      @muts.push Mutation.new(seqname,pos,ref,alt,t_ref_count,t_alt_count)
    end
  end
  line_class MuTect::Line
end
