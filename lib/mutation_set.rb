require 'yaml'
require 'intervals'
require 'hash_table'
require 'mutation'

class Mutation
  module Filtering
    def criteria_failed? obj, name
      return nil if !@table.mutation_config
      name = [ name ] if !name.is_a? Array
      crit = name.reduce(@table.mutation_config) do |h,n|
        h.is_a?(Hash) ? h[n] : nil
      end
      return nil if !crit
      crit.each do |attrib,value|
        return true if !criterion_ok? obj, attrib, value
      end
      nil
    end

    def criterion_ok? obj, attrib, value
      case attrib
      when /^min_(.*)/
        v = obj.send($1.to_sym).to_f
        return v >= value.to_f
      when /^max_(.*)/
        return obj.send($1.to_sym).to_f <= value.to_f
      when /^exclude_(.*)/
        v = obj.send($1.to_sym)
        if value.is_a? Array
          return value.none? { |r| v.match(/#{r}/) }
        else
          return v !~ /#{value}/
        end
      when /^has_(.*)/
        v = obj.send($1.to_sym)
        if value.is_a? Array
          return value.include? v
        elsif value == true
          return v && (v.is_a?(String) ? v.size > 0 : v)
        elsif value == false || value == "nil"
          return !v
        else
          return value == v
        end
      when /^include_(.*)/
        v = obj.send($1.to_sym)
        if value.is_a? Array
          return value.any? { |r| v.match(/#{r}/) }
        else
          return v =~ /#{value}/
        end
      when /^either.*/
        v = nil
        value.each do |attrib,val|
          v = true if criterion_ok? obj, attrib, val
        end
        return v
      when /^whitelisted/
        whitelist = @table.whitelist value
        return whitelist.intersect(self)
      when /^blacklisted/
        blacklist = @table.blacklist value
        return !blacklist.intersect(self)
      else
        # send it
        case value
        when "nil", false, nil
        return !obj.send(attrib.to_sym)
        when true
        return obj.send(attrib.to_sym)
        end
      end
      true
    end
  end
end

class Mutation
  class Record < HashTable::HashLine
    include GenomicLocus
    include Mutation::Filtering
    def copy
      self.class.new @hash.clone, @table
    end

    attr_reader :muts
    def initialize h, table
      super h, table
      @muts = []
    end

    def mut
      @muts.first
    end
  end

  class Collection < HashTable
    attr_reader :mutation_config
    class << self
      attr_reader :required, :optional
      def requires terms
        @required = terms
      end

      def might_have terms
        @optional = terms
      end

      def comments c
        @comment = c
      end
    end

    def clean_header s
      s.to_s.gsub(/\s+/,"_").gsub(/[^\w]+/,"").downcase.to_sym
    end

    def clean_headers
      @headers.map {|h| clean_header h}
    end

    def required
      self.class.required.keys
    end

    def initialize(obj=nil,opts={})
      # get types from required
      opts[:types] = types_from_required opts
      super obj, opts
      @mutation_config = YAML.load_file(opts[:mutation_config]) if opts[:mutation_config]
    end

    protected
    def types_from_required opts
      types = self.class.required ? self.class.required.clone : {}
      types = types.merge(self.class.optional.clone) if self.class.optional
      types.merge(opts[:types] || {})
    end

    def enforce_header
      create_sleeve
      raise "File lacks required headers: #{missing_required.join(", ")}" unless missing_required.empty?
    end

    def create_sleeve
      @sleeve = @header
      @header = @header.map do |h|
        clean_header h
      end
      raise "Headers are not unique: #{duplicate_headers.join(", ")}" unless duplicate_headers.empty?
      @sleeve = Hash[@header.zip @sleeve]
    end

    def duplicate_headers
      @header.inject(Hash.new(0)) do |count,h|
        count[h] += 1
        count
      end.select do |h,count|
        count > 1
      end.keys
    end

    def missing_required
      required - @header.map(&:downcase)
    end

    def post_read_hook
    end
  end
end
