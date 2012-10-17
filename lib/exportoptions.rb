#!/usr/bin/env ruby
# Copyright 2012 CopperEgg Corporation.  All rights reserved.
#
# exportoptions.rb is a utility to parse common command line options for the CopperEgg data export tools.
#
#
#encoding: utf-8

require 'optparse'
require 'ostruct'

class ExportOptions
  #
  # Return a structure containing the options.
  #
  def self.parse(args,usage_str,switch)
    # The options specified on the command line will be collected in *options*.
    # Set default values here.
    # The usage_str and switch allows us to call from different utilities

    options = OpenStruct.new

    now = Time.now.utc
    options.current_time = tnow = now.to_i
    options.start_hour = options.start_min = options.start_sec = 0
    options.end_hour = options.end_min = options.end_sec = 0

    options.interval = :pcm               # previous calendar month is the default
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

    options.metrics = nil
    options.outpath = "."
    options.apikey = ""
    options.verbose = false
    options.sample_size_override = 0      # max is 86400

    opts = OptionParser.new do |opts|
      opts.banner = usage_str

      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-o", "--outputpath [PATH]" , String, "Path to write CSV files") do |op|
        options.outpath = op.to_s
        $output_path =  options.outpath
      end

      if switch == 'systems'
        opts.on("--metrics x,y,z", Array, "Specify list of individual metrics",
                      "h,r,b,l,m,s,c,n,d,f,p default is all",
                      "h (health), r (running procs), b (blocked procs), l (load), m (memory)",
                      "s (swap), c (cpu), n (network io), d (disk io), f (filesystems), p (processes)") do |singles|
          options.metrics = singles
        end
      end

      # Specify sample time override
      opts.on("-s", "--sample_size [SECONDS]", Integer, "Override default sample size") do |ss|
        options.sample_size_override = ss
      end

      # Optional argument with keyword completion.
      opts.on("-i", "--interval [INTERVAL]", String,[:ytd, :pcm, :mtd, :last1d, :last7d, :last30d, :last60d, :last90d],
              "Select interval (ytd, pcm, mtd, last1d, last7d, last30d, last60d, last90d)",
              " ytd (year-to-date), pcm (previous calendar month), lastXd (last x days)") do |i|
        options.interval = i
        if i == :ytd                      # leave hours / secs / mins at 0 for this time frame
          options.start_year = now.year
          options.start_month = 1
          options.start_day = 1
          options.end_year = now.year
          options.end_month = now.month
          options.end_day = now.day
          if $verbose == true
            puts "Retrieving year to date data"
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
            puts "Retrieving data from previous calendar month"
          end
        elsif i == :mtd
          options.start_year = now.year
          options.start_month = now.month
          options.start_day = 1           # leave start hours, min and seconds at 0
          options.end_month = now.month
          options.end_day = now.day
          options.end_hour = now.hour     # leave min and sec at 0
          if $verbose == true
            puts "Retrieving calendar month to date data"
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
          tstrt = Time.at(tnow - (86400 * shave)).utc  # subtract shave * secs per day
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
          puts "\nUnecognized selection. Try using -h\n"
          return nil
        end
      end
      # Boolean switch.
      opts.on("-v", "--verbose", "Run verbosely") do
        options.verbose = true
        $verbose = true
      end

      opts.separator ""
      opts.separator "Common options:"

      # This will print an options summary.
      opts.on_tail("-h", "--help", "Show this message") do
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
    options
  end  # parse()
end  # class ExportOptions
