#!/usr/bin/env ruby
# Copyright 2012 CopperEgg Corporation.  All rights reserved.
#
# sysdata_csvexport.rb is a utility to export system data from CopperEgg to csv.
#
#
#encoding: utf-8

require 'rubygems'
require 'json'
require 'multi_json'
require 'pp'
require 'typhoeus'
require 'csv'
require './lib/exportoptions'
require './lib/getsystems'
require './lib/headers'

$output_path = "."
$APIKEY = ""
$outpath_setup = false
$verbose = false
$debug = false


def valid_json? json_
  begin
    JSON.parse(json_)
    return true
  rescue Exception => e
    return false
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
                       "s_d" => ["reads  KB/s", "writes  KB/s"],
                       "p"   => ["name", "internal","PID","UID","state","CPU % User",	"CPU % System",	"CPU % Total", "internal", 	"Memory Virtual", "Memory Resident", 	"internal",	"User UID",	"CPU % User",	"CPU % System", "CPU % Total", "internal use","	Memory Virtual", "Memory Resident",	"internal use"]
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
                       "s_d" => 2,
                       "p"   => 21
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

    keys = _keys
    keys_array = Array.new
    keys_array = keys.split(",")

    if ss != 0
      easy = Ethon::Easy.new(url: "https://"+_apikey.to_s+":U@api.copperegg.com/v2/revealcloud/samples.json?uuids="+_uuid.to_s+"&keys="+keys.to_s+"&starttime="+ts.to_s+"&endtime="+te.to_s+"&sample_size="+ss.to_s, followlocation: true, verbose: false, ssl_verifypeer: 0, headers: {Accept: "json"}, timeout: 10000)
    else
      easy = Ethon::Easy.new(url: "https://"+_apikey.to_s+":U@api.copperegg.com/v2/revealcloud/samples.json?uuids="+_uuid.to_s+"&keys="+keys.to_s+"&starttime="+ts.to_s+"&endtime="+te.to_s, followlocation: true, verbose: false, ssl_verifypeer: 0, headers: {Accept: "json"}, timeout: 10000)
    end # of 'if ss != 0'
    easy.prepare
    easy.perform

    case easy.response_code
      when 200
        if $verbose == true
          if ss == 0
            puts "Requested data for system id "+_uuid+"; start date " + Time.at(ts).utc.to_s + " ("+ts.to_s+"); end date " + Time.at(te).utc.to_s+" ("+te.to_s+"); default sample size\n"
          else
            puts "Requested data for system id "+_uuid+"; start date " + Time.at(ts).utc.to_s + "; end date " + Time.at(te).utc.to_s+"; sample size "+ ss.to_s+"\n"
          end # of 'if ss == 0'
        end # of 'if $verbose == true'

        if valid_json?(easy.response_body) != true
           puts "\nParse error: Invalid JSON.\n"
          return false
        end

        systemdata = JSON.parse(easy.response_body)

        if systemdata.is_a?(Array) != true
          puts "\nParse error: Expected an array.\n"
          return false
        elsif systemdata.length < 1
          puts "\nNo system data found.\n"
          return false
        elsif systemdata.length != 1
          puts "\nData from more than one system returned: Internal error.\n"
          return false
        end

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
            puts "system data actual start date "+ Time.at(base_time).utc.to_s + "; actual sample size " + sample_time.to_s + "\n"
          end

          incr = sample_time.to_i

          # create a master bucket list for this sample set, to detect missing samples
          buckets = Array.new         # contains timestamps indexed from 0 to numentries - 1
          bucketoff = Array.new       # contains offsets indexed from 0 to numentries - 1
          bucketcnt = 0
          off = 0
          t = ts

          while t <= te
            buckets[bucketcnt] = t
            bucketoff[bucketcnt] = off
            t = t + incr
            off = off + incr
            bucketcnt = bucketcnt + 1
          end

          inp_keyhash = Hash.new      # one of these is pulled from the onesystem hash, and processed separately

          # Loop through all metrics sets (keys)
          keys_array.each do |keystr|
            inp_keyhash = onesystem[keystr]     #inp_keyhash may have only samples (simple), or groups followed by samples (complex).

            fname = $output_path.to_s+"/"+ _systemname.to_s+"-"+keysto_strings[keystr]+".csv"
            if $verbose == true
              puts "Writing to "+fname.to_s+"\n\n"
            else
              print "."
            end

            # creating one .csv for each set of metrics
            CSV.open(fname.to_s, "wb") do |csv|
            hdrrow = nil
            row = Array.new

            if simple_syskeys.has_key?(keystr)
              hdrrow = CSVHeaders.create(simple_syskeys[keystr],[])
              csv << hdrrow

              numcats = simple_numcats[keystr]
              samples = inp_keyhash
              missctr = 0
              arrayctr = 0
              lastsample = 0
              firstsample = -1

              # step through the expected offsets
              while arrayctr < bucketcnt
                row[0] = Time.at(buckets[arrayctr].to_i).utc
                val = samples[bucketoff[arrayctr].to_s]
                if val.is_a?(Array) != true
                  tmpa = Array.new
                  tmpa[0] = val
                  val = tmpa
                end
                if val == nil
                  case numcats
                    when 1
                      row.concat([""])
                    when 2
                      row.concat(["", ""])
                    when 4
                      row.concat(["", "", "", ""])
                    when 9
                      row.concat(["", "", "", "", "", "", "", "", ""])
                    when 10
                      row.concat(["", "", "", "", "", "", "", "", "", ""])
                    when 21
                      row.concat(["", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""])
                  end
                  missctr = missctr + 1
                else
                  row.concat(val)
                  if firstsample == -1
                    firstsample = arrayctr
                  end
                  lastsample = arrayctr
                end
                csv << row
                row.clear
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
                hdrrow = CSVHeaders.create(complex_syskeys[keystr],names)
                csv << hdrrow

                missctr = 0
                arrayctr = 0
                lastsample = 0
                firstsample = -1

                # step through the expected offsets
                while arrayctr < bucketcnt
                  row[0] = Time.at(buckets[arrayctr].to_i).utc
                  ckeys.each do |ckey|
                    samples = inp_keyhash[ckey]
                    val = samples[bucketoff[arrayctr].to_s]

                    if val == nil
                      case numcats
                        when 1
                          row.concat([""])
                        when 2
                          row.concat(["", ""])
                        when 4
                          row.concat(["", "", "", ""])
                        when 9
                          row.concat(["", "", "", "", "", "", "", "", ""])
                        when 10
                          row.concat(["", "", "", "", "", "", "", "", "", ""])
                        when 21
                          row.concat(["", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""])
                      end
                      missctr = missctr + 1
                    else
                      row.concat(val)
                      if firstsample == -1
                        firstsample = arrayctr
                      end
                      lastsample = arrayctr
                    end
                  end  # of 'ckeys.each do'
                  csv << row
                  row.clear
                  arrayctr = arrayctr + 1
                end  # of 'while arrayctr < bucketcnt'
              end
            else
              if $debug == true
                puts "DEBUG:  Unsupported key: "+keystr+"\n"
              end
            end  # of 'complex_syskeys.has_key?(keystr)'
          end
          end  # of 'keys_array.each do'
        end  # end of 'else neither is nil'
      when 404
        puts "\n HTTP 404 error returned. Aborting ...\n"
      when 500...600
        puts "\n HTTP " +  easy.response_code.to_s +  " error returned. Aborting ...\n"
    end # end of switch on easy.response_code
    return false

  rescue Exception => e
    puts "system_samples exception ... error is " + e.message + "\n"
    return false
  end  # of begin
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

options = ExportOptions.parse(ARGV,"Usage: sysdata_csvexport.rb APIKEY [options]","systems")
if options != nil
  if $verbose == true
    pp options
    puts "\n"
  else
    puts "\n"
  end
  tr = Time.now
  tr = tr.utc

  trun = Time.gm(tr.year,tr.month,tr.day,tr.hour,tr.min,tr.sec)
  tstart = Time.gm(options.start_year,options.start_month,options.start_day,options.start_hour,options.start_min,options.start_sec)
  tend = Time.gm(options.end_year,options.end_month,options.end_day,options.end_hour,options.end_min,options.end_sec)

  if tstart.utc? == false
    tstart = tstart.utc
  end
  if tend.utc? == false
    tend = tend.utc
  end

  ts = tstart.to_i
  te = tend.to_i

  ss = options.sample_size_override

  if options.metrics == nil
    keys = "h,r,b,l,m,s,s_c,s_f,s_d,s_i"
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
  if $verbose
    print "Selected keys : "+keys+"\n"
  end
  puts  "Time and Date of this data export: "+trun.to_s+"\n"
  numberlive = 0
  livesystems = Array.new
  livesystems = GetSystems.all($APIKEY)

  if livesystems != nil
    numberlive = livesystems.length
    arrayindex = 0
    while arrayindex < numberlive
      uuid = livesystems[arrayindex]["uuid"]
      attrs = livesystems[arrayindex]["a"]
      # filter out those not updated during this period
      if attrs["p"] > ts
        hostname = attrs["n"]
        if hostname == nil
          hostname = uuid
        else
          hostname = hostname+"-"+uuid
        end
        tmpresult = syssamples_tocsv($APIKEY, uuid, attrs["n"],keys, ts, te, ss)
      end
      arrayindex = arrayindex + 1
    end # of 'while arrayindex < numberlive'
  else
    puts "find_systems returned nil\n"
  end # of 'if livesystems != nil'
end