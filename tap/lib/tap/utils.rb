require 'tempfile'

module Tap
  # Provides several shell utility methods for calling programs.
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
    
    # :::-
    # Run the system command +cmd+, passing the result to the block, if given.
    # Raises an error if the command fails. Uses the same semantics as 
    # Kernel::exec and Kernel::system.
    #
    # Based on FileUtils#sh from Rake.
    # :::+
    def sh(*cmd) # :yields: ok, status
      ok = system(*cmd)

      if block_given?
        yield(ok, $?)
      else
        ok or raise "Command failed with status (#{$?.exitstatus}): [#{ cmd.join(' ')}]"
      end
    end
  
    # Runs the system command +cmd+ using sh, redirecting the output to the 
    # specified file path.  Uses the redirection command:
    #
    #   "> \"#{path}\" 2>&1 #{cmd}"
    #
    # This redirection has been tested on Windows, OS X, and Fedora.  See 
    # http://en.wikipedia.org/wiki/Redirection_(Unix) for pointers on
    # redirection.  This style of redirection SHOULD NOT be used with
    # commands that contain other redirections.  
    def redirect_sh(cmd, path, &block) # :yields: ok, status
      sh( "> \"#{path}\" 2>&1 #{cmd}", &block)
    end
  
    # Runs the system command +cmd+ and returns the output as a string.
    def capture_sh(cmd, quiet=false, &block) # :yields: ok, status, tempfile_path
      tempfile = Tempfile.new('shell_utils')
      tempfile.close
      redirect_sh(cmd, tempfile.path) do |ok, status|
        if block_given?
          yield(ok, $?, tempfile.path)
        else
          ok or raise %Q{Command failed with status (#{$?.exitstatus}): [#{cmd}]
-------------- command output -------------------
#{File.read(tempfile.path)}
-------------------------------------------------
}
        end
      end
    
      quiet == true ? "" : File.read(tempfile.path)
    end
  end
end