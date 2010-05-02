require 'tempfile'

module Tap
  
  #
  # == Windows 
  # MSDOS has command line length limits specific to the version of Windows being
  # run (from http://www.ss64.com/nt/cmd.html):
  #
  # Windows NT:: 256 characters
  # Windows 2000::  2046 characters
  # Windows XP:: 8190 characters
  #
  # Commands longer than these limits fail, usually with something like: 'the input
  # line is too long'
  module Utils
    module_function
    
    def shellsplit(line, comment="#")
      words = []
      field = ''
      line.scan(/\G\s*(?>([^\s\\\'\"]+)|'([^\']*)'|"((?:[^\"\\]|\\.)*)"|(\\.?)|(\S))(\s|\z)?/m) do
        |word, sq, dq, esc, garbage, sep|
        raise ArgumentError, "Unmatched double quote: #{line.inspect}" if garbage
        break if word == comment
        field << (word || sq || (dq || esc).gsub(/\\(?=.)/, ''))
        if sep
          words << field
          field = ''
        end
      end
      words
    end
    
    # Sets the specified ENV variables and returns the *current* env.
    # If replace is true, current ENV variables are replaced; otherwise
    # the new env variables are simply added to the existing set.
    def set_env(env={}, replace=false)
      current_env = {}
      ENV.each_pair do |key, value|
        current_env[key] = value
      end
      
      ENV.clear if replace
      
      env.each_pair do |key, value|
        if value.nil?
          ENV.delete(key)
        else
          ENV[key] = value
        end
      end if env
      
      current_env
    end
    
    # Sets the specified ENV variables for the duration of the block.
    # If replace is true, current ENV variables are replaced; otherwise
    # the new env variables are simply added to the existing set.
    #
    # Returns the block return.
    def with_env(env={}, replace=false)
      current_env = nil
      begin
        current_env = set_env(env, replace)
        yield
      ensure
        if current_env
          set_env(current_env, true)
        end
      end
    end
    
    def sh_escape(str)
      str.to_s.gsub("'", "\\\\'").gsub(";", '\\;')
    end
    
    # Run the command with system and raise an error if it fails.
    def sh(*cmd)
      system(*cmd) or raise "Command failed with status (#{$?.exitstatus}): [#{cmd.join(' ')}]"
    end
  end
end