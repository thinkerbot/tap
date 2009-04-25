require 'tap/dump'
require 'tap/auditor'

module Tap
  module Tasks
    module Dump
      # :startdoc::task dumps an audit
      class Audit < Tap::Dump
        include Auditor::Auditable
        
        # Dumps the object to io as YAML.
        def dump(obj, io)
          Auditor::Audit.dump(obj, io)
        end
      end
    end
  end
end