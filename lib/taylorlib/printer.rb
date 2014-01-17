module Printer
  def write file, &block
    File.open(file,"w") do |f|
      output f, &block
    end
  end

  def print f=nil, &block
    if f
      write f, &block
    else
      output STDOUT, &block
    end
  end
end
