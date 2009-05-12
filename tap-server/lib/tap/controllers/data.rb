require 'tap/controllers/persistence'

module Tap
  module Controllers
    # ::controller
    class Data < Persistence
      set :default_layout, 'layout.erb'
      
      protected
      
      def type
        :data
      end
    end
  end
end