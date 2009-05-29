require 'tap/tasks/load'
require 'csv'

module Tap
  module Tasks
    class Load
      
      # :startdoc::task reads csv data
      #
      # Load CSV data as an array of arrays, selecting the specified rows and
      # columns.
      #
      class Csv < Load
      
        config :columns, nil, &c.range_or_nil
        config :rows, nil, &c.range_or_nil
        
        config :col_sep, nil, &c.string_or_nil
        config :row_sep, nil, &c.string_or_nil
        
        def load(io)
          
          data = CSV.parse(io.read, col_sep, row_sep)
          
          if rows
            data = data[rows]
          end
          
          if columns
            data.collect! do |cols|
              cols[columns]
            end
          end
          
          data
        end
        
      end 
    end
  end
end