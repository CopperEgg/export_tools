#!/usr/bin/env ruby
# Copyright 2012 CopperEgg Corporation.  All rights reserved.
#
# sysdata_csvexport.rb is a utility to export system data from CopperEgg to csv.
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

def valid_json? json_
  begin
    JSON.parse(json_)
  rescue Exception => e
    return nil
  end
end

# syssamples_tocsv
# this routine expects a single system id,
#   which may contain several sets of metric keys
#
def syssamples_tocsv(_apikey, _uuid, _systemname, _keys, ts, te, ss)
  begin
    simple_syskeys = {"h" => ["health index", "health state", "uptime state", "blocked state", "load state", "cpu state", "memory state", "state on last update", "filesystem health index",  "filesystem state"],
                      "r" => ["running procs"],
                      "b" => ["blocked procs"],
                      "l" => ["system load"],
                      "m" => ["buffer memory MB", "cache memory MB",  "free memory MB", "used memory MB"],
                      "s" => ["swap used MB", "swap free MB"]
                     }
    complex_syskeys = {"s_c" => ["active", "iowait","user", "nice", "system", "irq", "softirq", "steal", "guest"],
                       "s_i" => ["rx KB/s average", "tx KB/s average"],
                       "s_f" => ["used Gbytes", "free Gbytes"],
                       "s_d" => ["reads  KB/s", "writes  KB/s"]
                      }

    proc_syskeys    = {"p"   => ["name","cmd line","PID","UID","state","CPU % User",	"CPU % System",	"CPU % Total", "internal", 	"Memory Virtual", "Memory Resident", 	"internal"],
                       "u"   =>	["User UID",	"CPU % User",	"CPU % System", "CPU % Total", "internal use","	Memory Virtual", "Memory Resident",	"internal use"]
                      }

    simple_numcats =  {"h" => 10,
                      "r" => 1,
                      "b" => 1,
                      "l" => 1,
                      "m" => 4,
                      "s" => 2
                      }
    complex_numcats = {"s_c" => 9,
                       "s_i" => 2,
                       "s_f" => 2,
                       "s_d" => 2
                      }

    proc_numcats    = {"p"  => 12,
                       "u"  => 8
                      }


    keysto_strings =  { "h"   => "health",
                        "r"   => "run-procs",
                        "b"   => "block-procs",
                        "l"   => "sys-load",
                        "m"   => "memory",
                        "s"   => "swap",
                        "s_c" => "cpu",
                        "s_i" => "net",
                        "s_f" => "filesys",
                        "s_d" => "diskio",
                        "p"   => "procs"
                      }
    row_array = Array.new
    firstpass = true

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
          else
            if Dir.mkdir($output_path.to_s+"/",0775) == -1
              print "FAILED to create directiory "+$output_path.to_s+"/"+"\n"
              return false
            else
              FileUtils.chmod 0775, $output_path.to_s+"/"
            end
          end
        else  #  the directory exists
          FileUtils.chmod 0775, $output_path.to_s+"/"       # TODO only modify if needed?
       end # of 'if Dir.exists?($output_path.to_s+"/") == false'
      end
    end
    start = Time.now
    systemdata = GetSystemSamples.uuid( _apikey, _uuid, _keys, ts, te, ss)
    $times[$timed_calls] = Time.now - start
    $timed_calls += 1

    if systemdata == nil
      puts "\nSkipping " + _systemname.to_s + "\n"
    else
      keys = _keys
      keys_array = Array.new
      keys_array = keys.split(",")

      onesystem = Hash.new
      onesystem = systemdata[0]

     if (onesystem["_ts"] == nil) || (onesystem["_bs"] == nil)
        if $debug == true
          puts "_ts or _bs was nil. Skipping this system\n"
        end
      else  # else neither is nil
        base_time = onesystem["_ts"]
        sample_time = onesystem["_bs"]

        if $verbose == true
          puts "system data actual start date "+ Time.at(base_time).getlocal.to_s + "; actual sample size " + sample_time.to_s + "\n"
        end

        incr = sample_time.to_i

        # create a master bucket list for this sample set, to detect missing samples
        buckets = Array.new         # contains timestamps indexed from 0 to numentries - 1
        bucketoff = Array.new       # contains offsets indexed from 0 to numentries - 1
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
        while ctr <=  bucketcnt
          row_array[ctr] = Array.new
          ctr += 1
        end
        inp_keyhash = Hash.new      # one of these is pulled from the onesystem hash, and processed separately


        # Loop through all metrics sets (keys)
        keys_array.each do |keystr|
          inp_keyhash = onesystem[keystr]     #inp_keyhash may have only samples (simple), or groups followed by samples (complex).
          hdrrow = nil
          row = Array.new

          if simple_syskeys.has_key?(keystr)
            hdrrow = CSVHeaders.create('simple',simple_syskeys[keystr],[],firstpass)
            #csv << hdrrow
            row_array[0].concat(hdrrow)

            numcats = simple_numcats[keystr]
            samples = inp_keyhash
            missctr = 0
            arrayctr = 0
            lastsample = 0
            firstsample = -1

            # step through the expected offsets
            while arrayctr < bucketcnt
             #row[0] = Time.at(buckets[arrayctr].to_i).utc

              if firstpass == true
                row_array[arrayctr+1].concat([Time.at(buckets[arrayctr].to_i).getlocal])
              end

              val = samples[bucketoff[arrayctr].to_s]
              if val.is_a?(Array) != true
                tmpa = Array.new
                tmpa[0] = val
                val = tmpa
              end
              if val == nil
                case numcats
                  when 1
                      row_array[arrayctr+1].concat([""])
                  when 2
                      row_array[arrayctr+1].concat(["", ""])
                  when 4
                      row_array[arrayctr+1].concat(["", "", "", ""])
                  when 9
                     row_array[arrayctr+1].concat(["", "", "", "", "", "", "", "", ""])
                  when 10
                     row_array[arrayctr+1].concat(["", "", "", "", "", "", "", "", "", ""])
                end
                missctr = missctr + 1
              else
                row_array[arrayctr+1].concat(val)

                if firstsample == -1
                  firstsample = arrayctr
                end
                lastsample = arrayctr
              end
              arrayctr = arrayctr + 1
            end  # of 'while arrayctr < bucketcnt'

          elsif complex_syskeys.has_key?(keystr)
            numcats = complex_numcats[keystr]
            names = Array.new

            if inp_keyhash != nil
              ckeys = inp_keyhash.keys

              ctr = 0
              while ctr < inp_keyhash.length
                names[ctr] = ckeys[ctr].to_s
                ctr = ctr + 1
              end

              hdrrow = CSVHeaders.create('complex',complex_syskeys[keystr],names,firstpass)
              row_array[0].concat(hdrrow)

              missctr = 0
              arrayctr = 0
              lastsample = 0
              firstsample = -1

              # step through the expected offsets
              while arrayctr < bucketcnt
                if firstpass == true
                  row_array[arrayctr+1].concat([Time.at(buckets[arrayctr].to_i).getlocal])
                end
                ckeys.each do |ckey|
                  samples = inp_keyhash[ckey]
                  val = samples[bucketoff[arrayctr].to_s]

                  if val == nil
                    case numcats
                      when 1
                         row_array[arrayctr+1].concat([""])
                      when 2
                        row_array[arrayctr+1].concat(["", ""])
                      when 4
                         row_array[arrayctr+1].concat(["", "", "", ""])
                      when 9
                         row_array[arrayctr+1].concat(["", "", "", "", "", "", "", "", ""])
                      when 10
                         row_array[arrayctr+1].concat(["", "", "", "", "", "", "", "", "", ""])
                    end
                    missctr = missctr + 1
                  else
                     row_array[arrayctr+1].concat(val)
                    if firstsample == -1
                      firstsample = arrayctr
                    end
                    lastsample = arrayctr
                  end
                end  # of 'ckeys.each do'
                arrayctr = arrayctr + 1
              end  # of 'while arrayctr < bucketcnt'
            end
          elsif keystr == "p"
            if inp_keyhash != nil
              ckeys = [ "p", "u" ]

              missctr = 0
              arrayctr = 0
              lastsample = 0
              firstsample = -1
              max_pprocs = 0
              num_pprocs = 0
              max_uprocs = 0
              num_uprocs = 0

             # first run through all time samples, and find max number of pprocs and
              # max number of uprocs
              while arrayctr < bucketcnt
                samples = inp_keyhash[bucketoff[arrayctr].to_s]
                if samples != nil
                  newsamples = valid_json?(samples)
                  if newsamples != nil
                    samples = newsamples
                  end

                  pval = samples["p"]         # this is an array of arays
                  num_pprocs = pval.length

                  if num_pprocs > max_pprocs
                    max_pprocs = num_pprocs
                  end

                  uval = samples["u"]         # this is an array of arays
                  num_uprocs = uval.length

                  if num_uprocs > max_uprocs
                    max_uprocs = num_uprocs
                  end
                end
                arrayctr += 1
              end

              arrayctr = 0
              num_pprocs = 0
              num_uprocs = 0

               # step through the exp  ected offsets
              while arrayctr < bucketcnt
                if firstpass == true
                  row_array[arrayctr+1].concat([Time.at(buckets[arrayctr].to_i).getlocal])
                end

                samples = inp_keyhash[bucketoff[arrayctr].to_s]
                if samples != nil
                  newsamples = valid_json?(samples)
                  if newsamples != nil
                    samples = newsamples
                  end

                  pval = samples["p"]         # this is an array of arays
                  uval = samples["u"]
                  if pval != nil
                    num_pprocs = pval.length
                    excess = max_pprocs - num_pprocs

                    pctr = 0
                    while pctr < num_pprocs
                      if pval[pctr] == nil
                        row_array[arrayctr+1].concat(["", "", "", "", "", "", "", "", "", "", "", ""])
                      else
                        if pval[pctr].is_a?(Array)
                          row_array[arrayctr+1].concat(pval[pctr])
                          if firstsample == -1
                            firstsample = arrayctr
                          end
                          lastsample = arrayctr
                        else
                          if $debug == true
                            puts "\npctr is " + pctr.to_s + "; pval[pctr] is not an array : \n"
                            print "\n"
                          end
                        end
                      end
                      pctr += 1
                    end

                    if excess > 0
                      pctr = 0
                      while pctr < excess
                        row_array[arrayctr+1].concat(["", "", "", "", "", "", "", "", "", "", "", ""])
                        pctr += 1
                      end
                    end
                  end
                  uval = samples["u"]         # this is an array of arays

                  if uval != nil
                    num_uprocs = uval.length
                    excess = max_uprocs - num_uprocs

                    pctr = 0
                    while pctr < num_uprocs
                      if uval[pctr] == nil
                        row_array[arrayctr+1].concat(["", "", "", "", "", "", "", "", "", "", "", ""])
                      else
                        row_array[arrayctr+1].concat(uval[pctr])
                      end
                      pctr += 1
                    end

                    if excess > 0
                      pctr = 0
                      while pctr < excess
                        row_array[arrayctr+1].concat(["", "", "", "", "", "", "", "", "", "", "", ""])
                        pctr += 1
                      end
                    end
                  end
                end
                arrayctr = arrayctr + 1
              end  # of 'while arrayctr < bucketcnt'
              proc_ctr = 0
              while proc_ctr < max_pprocs
                hdrrow = CSVHeaders.create('simple', proc_syskeys["p"] ,[],firstpass)
                firstpass = false
                row_array[0].concat(hdrrow)
                proc_ctr += 1
              end
              proc_ctr = 0
              while proc_ctr < max_uprocs
                hdrrow = CSVHeaders.create('simple', proc_syskeys["u"] ,[],firstpass)
                firstpass = false
                row_array[0].concat(hdrrow)
                proc_ctr += 1
              end
            end
          else
            if $debug == true
              puts "DEBUG:  Unsupported key: "+keystr+"\n"
            end
          end  # of 'complex_syskeys.has_key?(keystr)'
          firstpass = false
        end  # of 'keys_array.each do'

        _systemname.gsub!('/','_')
        _systemname.gsub!('\\','_')

       fname = $output_path.to_s+"/"+ _systemname.to_s+".csv"
        if $verbose == true
          puts "Writing to "+fname.to_s+"\n\n"
        else
          print "."
        end

        CSV.open(fname.to_s, "wb", {:force_quotes => true}) do |csv|
          ctr = 0
          while ctr <= bucketcnt
            csv << row_array[ctr]
            ctr += 1
          end
        end
      end  # end of 'else neither is nil'
    end
 # rescue Exception => e
 #   puts "system_samples exception " + e.message + "\n"
 #   puts "\nSkipping " + _systemname.to_s + "\n"
  end  # of begin
  return true
end  # of system_samples

#
# This is the main portion of the sysdata_csvexport.rb utility
#

abrv_to_key =   { "h"   => "h",
                  "r"   => "r",
                  "b"   => "b",
                  "l"   => "l",
                  "m"   => "m",
                  "s"   => "s",
                  "c"   => "s_c",
                  "n"   => "s_i",
                  "f"   => "s_f",
                  "d"   => "s_d",
                  "p"   => "p"
                  }

options = ExportOptions.parse(ARGV,"Usage: sysdata_csvexport.rb APIKEY [options]","sysdata")
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
    keys = "h,r,b,l,m,s,s_c,s_f,s_d,s_i,p"
  else
    keys = ""
    options.metrics.each do |more|
      if keys == ""
        keys = abrv_to_key[more]
      else
        keys = keys+","+abrv_to_key[more]
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

  numberlive = 0
  livesystems = Array.new
  filteredsystems = Array.new

  if options.tag != ""
    # handle request for data from tagged systems
    puts  "Requesting systems with tag " + options.tag + "\n"
    livesystems = GetSystems.all($APIKEY)
    if livesystems == nil || livesystems == []
      puts "\nNo systems found.\n"
      exit
    end
    filteredsystems = systemsfilter_bytag(livesystems,options.tag)
    if filteredsystems == nil || filteredsystems == []
      puts "\nNo systems with tag " + options.tag + " found.\n"
      exit
    end
  elsif options.monitor != ""
    # handle request for data from single uuid
    puts  "Requesting system with UUID " + options.monitor.to_s + "\n"
    livesystems = GetSystems.all($APIKEY)
    if livesystems == nil
      puts "GetSystems returned nil\n"
      exit
    end
    filteredsystems = systemsfilter_byuuid(livesystems,options.monitor)
    if filteredsystems == nil || filteredsystems == []
      puts "\nSystem with UUID " + options.monitor.to_s + " not found.\n"
      exit
    end
  else
    # handle request for all systems
    puts  "Requesting all systems\n"
    livesystems = GetSystems.all($APIKEY)
    if livesystems == nil || livesystems == []
      puts "\nNo systems found.\n"
      exit
    end
    filteredsystems = livesystems
  end

  if filteredsystems != nil
    numberlive = filteredsystems.length
    arrayindex = 0
    while arrayindex < numberlive
      uuid = filteredsystems[arrayindex]["uuid"]
      attrs = filteredsystems[arrayindex]["a"]
      # filter out those not updated during this period
      if attrs != nil
        if attrs["p"] != nil
          if attrs["p"] > ts
            hostname = attrs["n"]
            if hostname == nil
              hostname = uuid
            else
              hostname = hostname+"-"+uuid
            end
            puts "uuid is " + uuid.to_s + "\n"
            tmpresult = syssamples_tocsv($APIKEY, uuid, attrs["n"],keys, ts, te, ss)
            if tmpresult == false
              exit
            end
          end
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
    puts "find_systems returned nil\n"
  end # of 'if filteredsystems != nil'
end