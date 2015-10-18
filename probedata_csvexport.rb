#!/usr/bin/env ruby
# Copyright 2012 IDERA.  All rights reserved.
#
# probedata_csvexport.rb is a utility to export probe data from Uptime Cloud Monitor to csv.
#
#
#encoding: utf-8

require 'rubygems'
require "json/pure"
require 'csv'
#require 'FileUtils'
require './lib/ver'
require './lib/exportoptions'
require './lib/headers'
require './lib/api'
require './lib/filters'

$output_path = "."
$APIKEY = ""
$outpath_setup = false
$verbose = false
$debug = false
$Max_Timeout = 120

$times = nil
$timed_calls = 0

def probedata_to_csv(row_array,probename)
  begin
    if $outpath_setup == false    # ensure the following happens only once
      $outpath_setup = true
      if $output_path != "."
        if Dir.exists?($output_path.to_s+"/") == false
          if $verbose == true
            print "Creating directory..."
            if Dir.mkdir($output_path.to_s+"/",0775) == -1
              print "** FAILED ***\n"
              return false
            else
              FileUtils.chmod 0775, $output_path.to_s+"/"
              print "Success\n"
            end
          else  # $verbose is off
            if Dir.mkdir($output_path.to_s+"/",0775) == -1
              print "FAILED to create directiory "+$output_path.to_s+"/"+"\n"
              return false
            else
              FileUtils.chmod 0775, $output_path.to_s+"/"
            end
          end  # of 'if $verbose == true'
        else  #  the directory exists
          FileUtils.chmod 0775, $output_path.to_s+"/"
        end  # of 'if Dir.exists?($output_path.to_s+"/") == false'
      end  # of 'if $output_path != "."'
    end  # of 'if $outpath_setup == false'

    probename.gsub!('/','_')
    probename.gsub!('\\','_')
    probename.gsub!(':','_')
    fname = $output_path.to_s+"/"+probename.to_s+".csv"
    if $verbose == true
      puts "Writing to "+fname.to_s+"\n\n"
    end

    CSV.open(fname.to_s, "wb") do |csv|
      ctr = 0
      while ctr < row_array.length
        csv << row_array[ctr]
        ctr += 1
      end
    end
    return true
  rescue Exception => e
    puts "probedata_to_csv exception ... error is " + e.message + "\n"
    return false
  end
end

# parse_probe_samples
# this routine expects a single probe id,
#   which may contain up to 4 sets of metric keys, with
#   data from up to 5 stations

def parse_probe_samples(_apikey, _id, _probename, _stations, _keys, ts, te, ss)
  begin

    complex_syskeys = {"s_s" => ["status codes"],
                       "s_u" => ["% uptime"],
                       "s_h" => ["health"],
                       "s_l" => ["connect time", "time to first byte", "transfer time", "total"]
                      }


    complex_numcats = {"s_s" => 1,
                       "s_u" => 1,
                       "s_h" => 1,
                       "s_l" => 4
                      }

    if $debug == true
      puts "DEBUG:  parse_probe_samples: " + _probename.to_s + "\n"
    end
    start = Time.now
    probe_samplehash = GetProbeSamples.probeid(_apikey, _id, _keys, ts, te, ss)
    $times[$timed_calls] = Time.now - start
    $timed_calls += 1

    row_array = Array.new
    firstpass = true
    if probe_samplehash == nil
      if $verbose == true
        puts "\nSkipping probe " + _probename.to_s + "\n"
      end
      return nil
    end

    keys = _keys
    keys_array = Array.new
    keys_array = keys.split(",")

    inp_stations = Array.new
    inp_stations = _stations
    total_station_cnt = inp_stations.length

    samplehash = probe_samplehash[0]
    if $debug == true
      puts "samplehash for probe " + _probename.to_s + "\n"
      p samplehash
      print "\n"
    end
    if samplehash == nil
      if $debug == true
        puts "samplehash is nil; skipping probe " + _probename.to_s + "\n"
      end
      return nil
    end
    base_time = samplehash["_ts"]
    sample_time = samplehash["_bs"]

    if (base_time == nil) || (sample_time == nil)
      if $debug == true
        puts "_ts or _bs was nil. Skipping probe " + _probename.to_s + "\n"
      end
      return nil
    end

    if $verbose == true
      puts "Probe data actual start date "+ Time.at(base_time).getlocal.to_s + "; actual sample size " + sample_time.to_s + "\n"
    end
    if $debug == true
      puts "DEBUG:  building buckets\n"
    end

    incr = sample_time.to_i

    # create a master bucket list for this probe, to detect missing samples
    buckets = Array.new
    bucketoff = Array.new
    bucketcnt = 0
    off = 0
# 4-21-2014
#        Handle the case where the instance data begins AFTER the start time
#       t = ts
        t = base_time

    while t <= te
      buckets[bucketcnt] = t
      bucketoff[bucketcnt] = off
      t = t + incr
      off = off + incr
      bucketcnt = bucketcnt + 1
    end

    ctr = 0
    while ctr <=  bucketcnt     # add one for the header row
      row_array[ctr] = Array.new
      ctr += 1
    end

    metric_hash = Hash.new
    station_hash = Hash.new

    # Loop through all metrics sets (keys)
    keys_array.each do |keystr|
      if $debug == true
        puts "\nDEBUG: beginning key " + keystr + "\n"
      end

      metric_hash = samplehash[keystr]
      if metric_hash == nil
        if $debug == true
          puts "\nDEBUG: nil metric_hash for metric key " + keystr + ":\n"
        end
        return nil
      end
      if metric_hash.empty? == false
        if $debug == true
          puts "metric_hash for key " + keystr.to_s + "\n"
          p metric_hash
          print "\n"
        end
        hdrrow = CSVHeaders.create('complex',complex_syskeys[keystr],inp_stations,firstpass)
        row_array[0].concat(hdrrow)

        # Loop through all monitoring stations
        inp_stations.each do |station|
          station_hash = metric_hash[station]
          if $debug == true
            puts "\nDEBUG: beginning station " + station + ":\n"
            puts "\nDEBUG: station_hash station " + station + "; key " + keystr.to_s + "\n"
            p station_hash
            print "\n"
          end
          if station_hash == nil
            if $debug == true
              puts "\nDEBUG: nil station_hash " + station + ":\n"
            end
            return nil
          end

          missctr = 0
          arrayctr = 0
          lastsample = 0
          firstsample = -1
          numcats = complex_numcats[keystr]

          # step through the expected offsets
          while arrayctr < bucketcnt
            if firstpass == true
              row_array[arrayctr+1].concat([Time.at(buckets[arrayctr].to_i).getlocal])
            end

            val = station_hash[bucketoff[arrayctr].to_s]
            if val == nil
              case numcats
                when 1
                  row_array[arrayctr+1].concat([""])
                when 4
                  row_array[arrayctr+1].concat(["", "", "", ""])
                else
                  if $debug == true
                    puts "\nDEBUG: numcats not 1 or 4\n"
                  end
                  return nil
              end
              missctr = missctr + 1
            else
              if val.is_a?(Array) != true
                tmpa = Array.new
                tmpa[0] = val
                val = tmpa
              end
              row_array[arrayctr+1].concat(val)

              if firstsample == -1
                firstsample = arrayctr
              end
              lastsample = arrayctr
            end
            arrayctr = arrayctr + 1
          end # end of this stations' samples
          firstpass = false
        end  # 'inp_stations.each do |station|'
      end # 'metric_hash.empty? == false'
    end  # end of 'keys_array.each do |keystr|'
    if $debug == true
      puts "header :\n"
      p row_array[0]
      puts "\n"
    end
  return row_array
  end
end


#
# This is the main portion of the probedata_csvexport.rb utility
#
options = ExportOptions.parse(ARGV,"Usage: probedata_csvexport.rb APIKEY [options]","probedata")
puts $VersionString

if options != nil
  tr = Time.now

  trun = Time.new(tr.year,tr.month,tr.day,tr.hour,tr.min,tr.sec)
  tstart = Time.new(options.start_year,options.start_month,options.start_day,options.start_hour,options.start_min,options.start_sec)
  tend = Time.new(options.end_year,options.end_month,options.end_day,options.end_hour,options.end_min,options.end_sec)

  tstart_local =  tstart
  tend_local = tend
  trun_local = trun

  ts = tstart.utc.to_i
  te = tend.utc.to_i

  ss = options.sample_size_override

  if options.metrics == nil
    keys = "s_h,s_u,s_s,s_l"
  else
    keys = ""
    options.metrics.each do |more|
      if keys == ""
        keys = more
      else
        keys = keys+","+ more
      end
    end
  end

  $times = Array.new
  $timed_calls = 0

  puts  "Time and Date of this data export: "+trun.to_s+"\n\n"
  puts  "Requesting data from " + tstart.getlocal.to_s + " to " + tend.getlocal.to_s + " local time\n"
  puts  "Requesting data from " + tstart.utc.to_s + " to " + tend.utc.to_s + "\n"
  puts  "Selected keys : "+keys+"\n"
  if ss == 0
    puts "Using defalt sample size\n"
  else
    puts "Sample size override is " + options.sample_size_override.to_s + "\n"
  end

  allprobes = Array.new
  filteredprobes = Array.new
  allprobes = GetProbes.all($APIKEY)
  if allprobes == nil || allprobes == []
    puts "\nNo probes found.\n"
    exit
  end

  if options.tag != ""
    # handle request for data from tagged probes
    filteredprobes = probesfilter_bytag(allprobes,options.tag)
    if filteredprobes == nil || filteredprobes == []
      puts "\nNo probes with tag " + options.tag + " found.\n"
      exit
    end
  elsif options.monitor != ""
    # handle request for data from single uuid
    filteredprobes = probesfilter_byid(allprobes,options.monitor)
    if filteredprobes == nil || filteredprobes == []
      puts "\nProbe with ID " + options.monitor.to_s + " not found.\n"
      exit
    end
  else
    # handle request for all systems
    filteredprobes = allprobes
  end

  row_array = Array.new

  if filteredprobes != nil
    numberlive = filteredprobes.length
    arrayindex = 0
    while arrayindex < numberlive
      this_probe = filteredprobes[arrayindex]
      if $verbose == false
        print "."
      end
      row_array =  parse_probe_samples($APIKEY, this_probe["id"], this_probe["probe_desc"], this_probe["stations"], keys, ts, te, ss)
      if row_array != nil && row_array.empty? == false
        tmpresult = probedata_to_csv(row_array,this_probe["probe_desc"])
      else
        if $debug == true
          puts "\n\nDEBUG: parse_probe_samples retuned nil! " + this_probe["probe_desc"].to_s +  "\n"
        end
      end
      arrayindex = arrayindex + 1
    end # of 'while arrayindex < numberlive'
    if $debug == true
      puts "\n\nexecutions times : \n"
      ctr = 0
      while ctr < $timed_calls
        puts $times[ctr].to_s + "\n"
        ctr = ctr + 1
      end
    end
  else
    puts "No systems found\n"
  end # of 'filteredprobes != nil
end
