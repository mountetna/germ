#!/usr/bin/env ruby
require 'fcs3_aux/fcs3_aux'

class Fcs3
  private
  include Fcs3Aux

  public
  attr_reader :text, :data
  def initialize file
    @io = File.open(file)

    read_fcs_header

    fix_fcs_header

    @text = get_text

    #fix_fcs_header_2

    @data = get_data
  end

  def inspect
    "#<#{self.class.name}:#{object_id} @data=#{@data.count}>"
  end

  def header
    @header ||= parameter_count.times.map do |i|
      @text["$P#{i+1}N"]
    end
  end

  private 
  def datatype
    @text["$DATATYPE"]
  end

  def datasize
    @text["$P1B"].to_i / 8
  end

  def parameter_count
    @text["$PAR"].to_i
  end

  def range
    @text["$P1R"].to_i
  end

  def bigendian?
    @text["$BYTEORD"] == "4,3,2,1"
  end

  def dataformat
    case datatype
    when 'F'
      bigendian? ? 'g' : 'e'
    when 'D'
      bigendian? ? 'G' : 'E'
    when 'I'
      (bytesize == 4 ? 'L' : 'S') + (bigendian? ? '<' : '>')
    end
  end

  def unpack_data bytes
    array = bytes.unpack( dataformat + '*' )
    array.each_slice(parameter_count).to_a
  end

  def fix_fcs_header
    [ :text, :data, :analysis ].each do |type|
      start = "@#{type}_start"
      stop = "@#{type}_end"
      instance_variable_set(start, instance_variable_get(start).to_i)
      instance_variable_set(stop, instance_variable_get(stop).to_i)
    end
  end

  def fix_fcs_header_2
    @data_start = @text["$BEGINDATA"].to_i
    @data_end = @text["$ENDDATA"].to_i
  end
end
