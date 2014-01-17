module DataTypes
  def attr_accessor_of_type name, type=nil
    send :define_method, name do
      instance_variable_get("@#{name}")
    end
    send :define_method, "#{name}=" do  |v|
      if block_given?
        instance_variable_set "@#{name}", yield(v) 
      else
        if v.respond_to? type
          instance_variable_set "@#{name}", v.send(type)
        else
          raise ArgumentException
        end
      end
    end
  end

  def attr_string *names
    names.each do |name|
      attr_accessor_of_type name, :to_s
    end
  end
  def attr_integer *names
    names.each do |name|
      attr_accessor_of_type name, :to_i
    end
  end

  def attr_sym *names
    names.each do |name|
      attr_accessor_of_type name, :to_sym
    end
  end

  def attr_array *names
    names.each do |name|
      attr_accessor_of_type name do |v|
        if block_given?
          yield v
        else
          v.split(//)
        end
      end
    end
  end
end
