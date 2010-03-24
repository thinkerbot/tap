require 'tap/tasks/dump'
require 'csv'

module Tap
  module Tasks
    class Dump
      
      # :startdoc::task dumps data as csv
      #
      # Dumps arrays as CSV data.  Each array passed to dump will be formatted
      # into a single line of csv, ie multiple dumps build the csv results.
      # Non-array objects are converted to arrays using to_ary.
      #
      #   % tap load/yaml '["a", "b", "c"]' -: dump/csv
      #   a,b,c
      #
      class Csv < Dump
        
        config :col_sep, ",", :short => :c, &c.string    # The column separator (",")
        config :row_sep, $/, :short => :r, &c.string     # The row separator ("\n")
        
        def dump(data, io)
          io << generate_line(data.to_ary)
        end
        
        private
        
        if RUBY_VERSION >= '1.9'
          def generate_line(data)
            CSV.generate_line(data, :col_sep => col_sep, :row_sep => row_sep)
          end
        else
          def generate_line(data)
            CSV.generate_line(data, col_sep) + row_sep
          end
        end
      end
    end
  end
end