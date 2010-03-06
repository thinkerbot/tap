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
      #   % tap load/csv 'a,b,c.d,e,f' --row-sep '.' -: inspect
      #   [["a", "b", "c"], ["d", "e", "f"]]
      # 
      # Note this task is quite inefficient in that it will load all data
      # before making a selection; large files or edge selections may benefit
      # from an alternate task.
      #
      class Csv < Load
        
        config :columns, nil, :short => :C, &c.range_or_nil   # Specify a range of columns
        config :rows, nil, :short => :R, &c.range_or_nil      # Specify a range of rows
        
        config :col_sep, nil, :short => :c, &c.string_or_nil  # The column separator (",")
        config :row_sep, nil, :short => :r, &c.string_or_nil  # The row separator ("\r\n" or "\n")
        
        # Loads the io data as CSV, into an array of arrays.
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