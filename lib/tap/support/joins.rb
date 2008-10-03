require 'tap/support/join'

module Tap
  module Support
    
    # A module of the standard Join classes supported by Tap.
    module Joins
      autoload(:Sequence, 'tap/support/joins/sequence')
      autoload(:Fork, 'tap/support/joins/fork')
      autoload(:Merge, 'tap/support/joins/merge')
      autoload(:SyncMerge, 'tap/support/joins/sync_merge')
      autoload(:Switch, 'tap/support/joins/switch')  
    end
  end
end