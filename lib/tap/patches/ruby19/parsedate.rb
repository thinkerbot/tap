require 'date/format'

# Taken directly from the Ruby 1.8.6 standard library.  Ruby 1.9 has apparently
# eliminated this class, but it is currently (2008-02-08) required by ActiveSupport.
#
# Making this file available to ActiveSupport allows testing under Ruby 1.9,
# but this patch should be unnecessary when ActiveSupport upgrades and becomes
# compatible with Ruby 1.9
module ParseDate # :nodoc:
  def parsedate(str, comp=false)
    Date._parse(str, comp).
      values_at(:year, :mon, :mday, :hour, :min, :sec, :zone, :wday)
  end

  module_function :parsedate
end
