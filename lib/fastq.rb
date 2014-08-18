#!/usr/bin/env ruby
require 'zlib'

class Fastq
  class Read
    attr_reader :id, :seq, :qual
    def initialize id, seq, qual
      @id = id
      @seq = seq
      @qual = qual
    end
  end
  def initialize file
    if is_gzipped?(file)
      @io = IO.popen("zcat #{file}")
    else
      @io = File.open file
    end
  end

  def each_read
    while read = get_read
      yield read
    end
  end

  def get_read
    return nil unless id = @io.gets
    seq = @io.gets
    plus = @io.gets
    qual = @io.gets
    Fastq::Read.new *[ id, seq, qual ].map(&:chomp)
  end

  private
  def is_gzipped? file
    return nil unless file && File.readable?(file)
    begin
      Zlib::GzipReader.new(File.open file).close
    rescue Zlib::GzipFile::Error => e
      return nil
    end
    true
  end
end
