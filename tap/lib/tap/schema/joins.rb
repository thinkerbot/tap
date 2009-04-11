require 'tap/support/join'

module Tap
  module Support
    
    # A module of the standard Join classes supported by Tap.
    module Joins
      autoload(:SyncMerge, 'tap/support/joins/sync_merge')
      autoload(:Switch, 'tap/support/joins/switch')  
    end
  end
end