require 'cgi'
require 'strscan'

class UrlEncodedPairParser < StringScanner #:nodoc:
  attr_reader :top, :parent, :result

  def initialize(pairs = [])
    super('')
    @result = {}
    pairs.each { |key, value| parse(key, value) }
  end

  KEY_REGEXP = %r{([^\[\]=&]+)}
  BRACKETED_KEY_REGEXP = %r{\[([^\[\]=&]+)\]}

  # Parse the query string
  def parse(key, value)
    self.string = key
    @top, @parent = result, nil

    # First scan the bare key
    key = scan(KEY_REGEXP) or return
    key = post_key_check(key)

    # Then scan as many nestings as present
    until eos?
      r = scan(BRACKETED_KEY_REGEXP) or return
      key = self[1]
      key = post_key_check(key)
    end

    bind(key, value)
  end

  private
  # After we see a key, we must look ahead to determine our next action. Cases:
  #
  # [] follows the key. Then the value must be an array.
  # = follows the key. (A value comes next)
  # & or the end of string follows the key. Then the key is a flag.
  # otherwise, a hash follows the key.
  def post_key_check(key)
    if scan(/\[\]/) # a[b][] indicates that b is an array
      container(key, Array)
      nil
    elsif check(/\[[^\]]/) # a[b] indicates that a is a hash
      container(key, Hash)
      nil
    else # End of key? We do nothing.
      key
    end
  end

  # Add a container to the stack.
  def container(key, klass)
    type_conflict! klass, top[key] if top.is_a?(Hash) && top.key?(key) && ! top[key].is_a?(klass)
    value = bind(key, klass.new)
    type_conflict! klass, value unless value.is_a?(klass)
    push(value)
  end

  # Push a value onto the 'stack', which is actually only the top 2 items.
  def push(value)
    @parent, @top = @top, value
  end

  # Bind a key (which may be nil for items in an array) to the provided value.
  def bind(key, value)
    if top.is_a? Array
      if key
        if top[-1].is_a?(Hash) && ! top[-1].key?(key)
          top[-1][key] = value
        else
          top << {key => value}#.with_indifferent_access
          push top.last
        end
      else
        top << value
      end
    elsif top.is_a? Hash
      key = CGI.unescape(key)
      parent << (@top = {}) if top.key?(key) && parent.is_a?(Array)
      return top[key] ||= value
    else
      raise ArgumentError, "Don't know what to do: top is #{top.inspect}"
    end

    return value
  end

  def type_conflict!(klass, value)
    raise TypeError, "Conflicting types for parameter containers. Expected an instance of #{klass} but found an instance of #{value.class}. This can be caused by colliding Array and Hash parameters like qs[]=value&qs[key]=value."
  end
end