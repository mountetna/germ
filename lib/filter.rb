class Filter
  def initialize crit
    @crit = crit
  end

  def passes? obj
    !fails? obj
  end

  def fails? obj
    @crit.any? do |rule,value|
      !criterion_ok? obj, rule, value
    end
  end

  def criterion_ok? obj, rule, expected
    case rule
    when /^min_(.*)/
      v = obj.send($1.to_sym).to_f
      return v >= expected.to_f
    when /^max_(.*)/
      return obj.send($1.to_sym).to_f <= expected.to_f
    when /^exclude_(.*)/
      v = obj.send($1.to_sym)
      if expected.is_a? Array
        return expected.none? { |r| v.match(/#{r}/) }
      else
        return v !~ /#{expected}/
      end
    when /^has_(.*)/
      v = obj.send($1.to_sym)
      if expected.is_a? Array
        return expected.include? v
      elsif expected == true
        return v && (v.is_a?(String) ? v.size > 0 : v)
      elsif !expected || expected == "nil"
        return !v || (v.is_a?(String) && v.size == 0)
      else
        return expected == v
      end
    when /^include_(.*)/
      v = obj.send($1.to_sym)
      if expected.is_a? Array
        return expected.any? { |r| v.match(/#{r}/) }
      else
        return v =~ /#{expected}/
      end
    when /^either.*/
      v = nil
      expected.each do |rule,val|
        v = true if criterion_ok? obj, rule, val
      end
      return v
    else
      # send it
      case expected
      when "nil", false, nil
      return !obj.send(rule.to_sym)
      when true
      return obj.send(rule.to_sym)
      end
    end
    true
  end
end
