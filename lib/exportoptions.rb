#!/usr/bin/env ruby
# Copyright 2012 IDERA.  All rights reserved.
#
# exportoptions.rb is a utility to parse common command line options for the Uptime Cloud Monitor data export tools.
#
#
#encoding: utf-8

require 'optparse'
require 'ostruct'
require 'date'

def string_to_time time_, format_
 time = Date._strptime(time_, format_)
 return Time.local(time[:year], time[:mon], time[:mday], time[:hour], time[:min], time[:sec], time[:sec_fraction], time[:zone])
end

class ExportOptions
  #
  # Return a structure containing the options.
  #
  def self.parse(args,usage_str,switch)
    # The options specified on the command line will be collected in *options*.
    # Set default values here.
    # The usage_str and switch allows us to call from different utilities

    options = OpenStruct.new

    options.interval = ""
    options.begintime = ""
    options.endtime = ""
    options.tag = ""
    options.metrics = nil
    options.monitor = ""
    options.outpath = "."
    options.apikey = ""
    options.verbose = false
    options.debug = false
    options.per_page = 200
    options.page_number = 1
    options.sample_size_override = 0      # max is 86400

    opts = OptionParser.new do |opts|
      opts.banner = usage_str

      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-o", "--outputpath [PATH]" , String, "Path to write CSV files") do |op|
        options.outpath = op.to_s
        $output_path =  options.outpath
      end

      if (switch == 'sysdata') || (switch == 'probedata' || (switch=='issue'))

        unless switch=='issue'
          opts.on("-u", "--UUID [IDENTIFIER]" , String, "The UUID of the system or probe whose data to export.",
                        "Should not be used wth the -t option.") do |op|
            options.monitor = op.to_s
          end

          opts.on("-t", "--tagstring [TAG]" , String, "Return data from the systems or probes with this tag.",
                      "If not entered, data from all systems / probes will be exported." ) do |op|
            options.tag = op.to_s
          end
          # Specify sample time override
          opts.on("-s", "--sample_size [SECONDS]", Integer, "Override default sample size") do |ss|
            options.sample_size_override = ss
          end
          opts.on("-i", "--interval [INTERVAL]", String,[:ytd, :pcm, :mtd, :last1d, :last7d, :last30d, :last60d, :last90d, :last6m, :last12m],
                  "Select interval (ytd, pcm, mtd, last1d, last7d, last30d, last60d, last90d, last6m, last12m)",
                  " ytd (year-to-date), pcm (previous calendar month), lastXd (last x days)") do |i|
            options.interval = i
          end
        else
          opts.on("-n", "--page_number [INTEGER]" , Integer, "The page number of the paginated result" ) do |op|
            options.page_number = op
          end
          opts.on("-p", "--per_page [INTEGER]" , Integer, "The number of results you would like to get in one call. Maximum " +
            "and default value is 200") do |op|
            options.per_page = op
          end
        end

        opts.on("-b", "--begin [DATE]" , String, "Begin time of exported data. %Y-%m-%d %H:%M",
                        "For example, -b 2013-1-1 00:00  Your entry should be in your local time",
                        "Use this option along with the -e End option. Cannot use this option if -i option is used.")  do |op|
          options.begintime = op.to_s
        end

        opts.on("-e", "--end [DATE]" , String, "End time of exported data. %Y-%m-%d %H:%M",
                        "For example, -e 2013-3-1 00:00  Your entry should be in your local time",
                        "Use this option along with the -b option. Cannot use this option if -i option is used.")  do |op|
          options.endtime = op.to_s
        end

      end

      if switch == 'sysdata'
        opts.on("--metrics x,y,z", Array, "Specify list of individual metrics",
                      "h,r,b,l,m,s,c,n,d,f,p default is all",
                      "h (health), r (running procs), b (blocked procs), l (load), m (memory)",
                      "s (swap), c (cpu), n (network io), d (disk io), f (filesystems), p (processes)") do |singles|
          options.metrics = singles
        end
      elsif switch == 'probedata'
        opts.on("--metrics x,y,z", Array, "Specify list of individual metrics",
                      "s_h (health), s_l (latencies), s_s (status codes), s_u (uptime)") do |singles|
          options.metrics = singles
        end
      end

      # Boolean switch.
      opts.on("-v", "--verbose", "Run verbosely") do
        options.verbose = true
        $verbose = true
      end
      opts.on("-d", "--debug", "Run with debug output") do
        options.debug = true
        $debug = true
      end

      opts.separator ""
      opts.separator "Common options:"

      # This will print an options summary.
      opts.on_tail("-h", "--help", "Show this message") do
        puts $VersionString
        puts opts
        exit
      end
    end
    if ARGV[0] == nil
      puts usage_str + "\n"
      return nil
    else
      $APIKEY = ARGV[0]
      if $APIKEY == ""
        puts usage_str + "\n"
        return nil
      end
    end
    opts.parse!(args)

    # processing time and other options
    now = Time.now                    # options values will be in local time
    options.start_hour = options.start_min = options.start_sec = 0
    options.end_hour = options.end_min = options.end_sec = 0

    if options.interval == "" && options.begintime == ""
      # no interval or begintime entered. Default to last 1d
      secs = now.sec          # knock off 15 minutes ... this is historical data
      secs = secs + (15*60)
      tend = now - secs
      tend = tend.getlocal

      tstrt = Time.at(tend - 86400)   # subtract 1 * secs per day
      tstrt = tstrt.getlocal
      options.start_year  = tstrt.year
      options.start_month = tstrt.month
      options.start_day   = tstrt.day
      options.start_hour  = tstrt.hour
      options.start_min   = tstrt.min
      options.start_sec   = tstrt.sec
      options.end_year    = now.year
      options.end_month   = now.month
      options.end_day     = now.day
      options.end_hour    = now.hour
      options.end_min     = now.min
      options.end_sec     = now.sec
      if $verbose == true
        puts "Retrieving data from the last 24 hours\n"
      end
    elsif options.interval != ""
      if (options.begintime != "") || (options.endtime != "")
        puts "Using the interval specified; ignoring begintime and endtime.\n"
      end
      # Processing of interval shortcuts goes here
      i = options.interval
      if i == :ytd                      # leave hours / secs / mins at 0 for this time frame
        options.start_year = now.year
        options.start_month = 1
        options.start_day = 1
        options.end_year = now.year
        options.end_month = now.month
        options.end_day = now.day
        if $verbose == true
          puts "Retrieving year to date data\n"
        end
      elsif i == :pcm                    # leave hours / secs / mins at 0 for this time frame
        if now.month == 1
          options.start_month = 12
          options.end_month = 1
          options.start_year = now.year-1
          options.end_year = now.year
        else
          options.start_month = now.month-1
          options.end_month = now.month
          options.start_year = now.year
          options.end_year = now.year
        end
        options.start_day = options.end_day = 1
        if $verbose == true
          puts "Retrieving data from previous calendar month\n"
        end
      elsif i == :mtd
        options.start_year = now.year
        options.start_month = now.month
        options.start_day = 1           # leave start hours, min and seconds at 0
        options.end_month = now.month
        options.end_day = now.day       # leave end hours, min and sec at 0
        if $verbose == true
          puts "Retrieving calendar month to date data\n"
        end
      elsif i == :last6m
        if now.month >=7
          options.start_month = now.month - 6
          options.end_month = now.month
          options.start_day = 1           # leave start hours, min and seconds at 0
          options.end_day = 1             # leave end hours, min and sec at 0
          options.start_year = now.year
          options.end_year = now.year
        else
          options.start_month = now.month+6
          options.end_month = now.month
          options.start_day = 1           # leave start hours, min and seconds at 0
          options.end_day = 1             # leave end hours, min and sec at 0
          options.start_year = now.year-1
          options.end_year = now.year
        end
        if $verbose == true
          puts "Retrieving data for the past 6 months\n"
        end
      elsif i == :last12m
        options.start_month = now.month
        options.end_month = now.month
        options.start_day = 1           # leave start hours, min and seconds at 0
        options.end_day = 1             # leave end hours, min and sec at 0
        options.start_year = now.year
        options.end_year = now.year-1
        if $verbose == true
          puts "Retrieving data for the past 12 months\n"
        end
      elsif i == :last1d || i == :last7d || i == :last30d || i == :last60d || i == :last90d
        case i
          when :last1d
            shave = 1
          when :last7d
            shave = 7
          when :last30d
            shave = 30
          when :last60d
            shave = 60
          when :last90d
            shave = 90
        end # if 'case i'

        secs = now.sec          # knock off 15 minutes ... this is supposed to be historical data
        secs = secs + (15*60)
        tend = now - secs
        tend = tend.getlocal

        tstrt = Time.at(tend - (86400 * shave))   # subtract shave * secs per day
        tstrt = tstrt.getlocal
        options.start_year  = tstrt.year
        options.start_month = tstrt.month
        options.start_day   = tstrt.day
        options.start_hour  = tstrt.hour
        options.start_min   = tstrt.min
        options.start_sec   = tstrt.sec
        options.end_year    = now.year
        options.end_month   = now.month
        options.end_day     = now.day
        options.end_hour    = now.hour
        options.end_min     = now.min
        options.end_sec     = now.sec
        if $verbose == true
          if shave == 1
            puts "Retrieving data from the last 24 hours\n"
          else
            puts "Retrieving data from the last "+shave.to_s+" days\n"
          end
        end
      else
        puts "\nUnecognized interval selection. Try using -h\n"
        exit
      end
    else
      # begintime is not nil
      begin
        tb = string_to_time(options.begintime, '%Y-%m-%d %H:%M')
       # p tb
       # p tb.utc
      rescue
        puts "\nError parsing begintime. Must be formatted like this:  2012-12-15 16:00\n"
        exit
      end
      tstrt = tb.getlocal
      if options.endtime == ""
        secs = now.sec          # knock off 15 minutes ... this is supposed to be historical data
        secs = secs + (15*60)
        tend = now - secs
        tend = tend.getlocal
      else
        begin
          te = string_to_time(options.endtime, '%Y-%m-%d %H:%M')
         # p te
         # p te.utc
        rescue
          puts "\nError parsing endtime. Must be formatted like this:  2012-12-15 16:00\n"
          exit
        end
        tend = te.getlocal
      end
      options.start_year  = tstrt.year
      options.start_month = tstrt.month
      options.start_day   = tstrt.day
      options.start_hour  = tstrt.hour
      options.start_min   = tstrt.min
      options.start_sec   = 0
      options.end_year    = tend.year
      options.end_month   = tend.month
      options.end_day     = tend.day
      options.end_hour    = tend.hour
      options.end_min     = tend.min
      options.end_sec     = 0
    end

    options
  end  # parse()
end  # class ExportOptions
