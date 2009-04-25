module Rap
  module Utils
    # Run the system command +cmd+, passing the result to the block, if given.
    # Raises an error if the command fails. Uses the same semantics as 
    # Kernel::exec and Kernel::system.
    #
    # Based on FileUtils#sh from Rake.
    def sh(*cmd) # :yields: ok, status
      ok = system(*cmd)

      if block_given?
        yield(ok, $?)
      else
        ok or raise "Command failed with status (#{$?.exitstatus}): [#{cmd.join(' ')}]"
      end
    end
  end
end