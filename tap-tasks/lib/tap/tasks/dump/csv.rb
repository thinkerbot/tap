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
        config :row_sep, "\n", :short => :r, &c.string   # The row separator ("\n")
        
        # Dumps the data to io as CSV.  Data is converted to an array using
        # to_ary.
        def dump(data, io)
          io << CSV.generate_line(data.to_ary, col_sep) + row_sep
        end
      end
    end
  end
end