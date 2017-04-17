class Flagstat
  include Enumerable

  STATS = [ :total, :duplicates, :mapped, :paired_in_sequence, :read1, :read2, 
    :properly_paired, :both_mapped, :singletons,
    :mate_mapped_chr, :mate_mapped_chr_highq ]
  STATS.each do |method|
    define_method method do
      @flags[method].first.to_i
    end
    define_method :"chastity_#{method}" do
      @flags[method].last.to_i
    end
  end

  def initialize file
    @flags = Hash[
      STATS.zip(
        File.foreach(file).each_with_index.map do |l|
          l.scan(/([0-9]+) \+ ([0-9]+)/).flatten
        end
      )
    ]
  end

  def each
    @flags.each do |f,l|
      yield f,l
    end
  end
end
