require 'zlib'
require 'extlib'
require 'germ/printer'
require 'hash_table_aux/hash_table_aux'

class HashTable
  class ColumnArray < Array
  end
  module Columns
    def header_string
      if preamble.empty?
        formatted_columns
      else
        [ preamble, formatted_columns ].join("\n")
      end
    end

    def add_column *columns
      @columns.concat columns

      @column_set = nil
    end
    alias_method :add_columns, :add_column

    def has_column? column
      column_set.include? column
    end

    protected
    def preamble
      @preamble
    end

    def set_parsed_columns names
      if @columns.empty? || use_parsed_columns?
        @columns = names.map do |name|
          clean_column_name name
        end
        set_parsed_display_names @columns, names

        validate_columns
      end

      @columns
    end

    def use_parsed_columns?
      @opts[:parse_mode] == :parsed
    end

    def lacks_header?
      @opts[:parse_mode] == :noheader
    end

    def set_parsed_display_names columns, names
      @display_names.update( Hash[columns.zip(names)] )
    end

    def formatted_columns
      @columns.map do |name|
        @display_names[name] || name
      end.join("\t")
    end

    def column_set
      @column_set ||= Set.new(@columns + @columns.map(&:to_s))
    end


    def create_sleeve 
      if self.class.use_sleeve?
        @formatted_names = Hash[clean_columns.zip @columns]
        @columns = clean_columns
      else
        @formatted_names = Hash[@columns.zip @columns]
      end
    end

    def clean_column_name name
      name.to_s
        .gsub(/(\.|\s+)/,"_")
        .gsub(/[^\w]+/,"")
        .downcase
        .to_sym
    end

    def set_types types
      @types = types

      validate_types
    end

    def validate_types
      raise TypeError, "Types must be a Hash!" unless @types.is_a?(Hash)

      @types.each do |key,type|
        case type
        when Array
          raise ArgumentError unless (1..2).include?(type.length) && type.all?{|n| n.is_a? String}
        when :float, :int, :str, :sym
        else
          raise ArgumentError "Unknown type specified."
        end
      end
    end

    def validate_columns
      raise "Duplicate columns found!" unless columns.uniq.length == columns.length
      raise "Required columns are missing!\n#{@required - columns}" unless (@required - columns).empty?
    end
  end
end
