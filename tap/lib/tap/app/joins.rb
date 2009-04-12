require 'tap/schema/join'

module Tap
  class Schema
    
    # A module of the standard Join classes supported by Tap.
    module Joins
      autoload(:SyncMerge, 'tap/schema/joins/sync_merge')
      autoload(:Switch, 'tap/schema/joins/switch')  
    end
  end
end