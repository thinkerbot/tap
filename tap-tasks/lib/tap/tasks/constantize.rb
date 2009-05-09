require 'tap/task'
require 'tap/env/constant'

module Tap
  module Tasks
    # :startdoc::task
    class Constantize < Tap::Task
      Constant = Tap::Env::Constant
      
      def process(const_name, require_path=nil)
        Constant.new(const_name, require_path).constantize
      end
    end
  end
end