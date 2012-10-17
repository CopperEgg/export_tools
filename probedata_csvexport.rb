#!/usr/bin/env ruby
# Copyright 2012 CopperEgg Corporation.  All rights reserved.
#
# probedata_csvexport.rb is a utility to export probe data from CopperEgg to csv.
#
#
#encoding: utf-8

require 'rubygems'
require 'json'
require 'typhoeus'
require 'csv'
require './lib/exportoptions'
require './lib/getprobes'

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

def state_to_s _state
  @str = nil
  case _state
    when 0
      @str = 'unknown'
    when 1
      @str = 'ok'
    when 2
      @str = 'warn'
    when 3
      @str = 'critical'
  end
  if @str == nil
    puts "Unrecognized state: "+_state.to_s+"/n"
    @str = "???"
  end
  return @str
end

def stamap _abrv
  @str = nil
  case _abrv
    when "atl"
      @str = "Atlanta"
    when "nrk"
      @str = "Newark"
    when "lon"
      @str = "London"
    when "fre"
      @str = "Fremont"
    when "dal"
      @str = "Dallas"
    when "tok"
      @str = "Tokyo"
  end
  if @str == nil
    puts "Unrecognized Station: "+_abrv.to_s+"/n"
    @str = "???"
  end
  return @str
end

def nonil _this
  if _this == nil
    return ""
  else
    return _this
  end
end

=begin
  probedata_to_csv will create one .csv file, containing data for one metric, in the specified output directory.
  The filename will be probename-metric.csv
=end

def probedata_to_csv(metrichash, probename, metric)
  begin
    if $debug == true
      puts "At start of probedata_to_csv and output path is "+$output_path.to_s+"\n"
    end
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

    fname = $output_path.to_s+"/"+probename.to_s+"-"+metric.to_s+".csv"
    if $verbose == true
      puts "Writing to "+fname.to_s+"\n\n"
    end

    CSV.open(fname.to_s, "wb") do |csv|

      station_num = metrichash.length
      stationkeys = metrichash.keys

      if station_num  < 1
        puts "No station data found!\n"
        return false
      end # of ' if station_num < 1'

      row0 = Array.new
      row0[0] = "Date & Time UTC"
      colctr = 1
      sctr = 0
      while sctr < station_num
        row0[colctr]=stationkeys[sctr].to_s + "  "+metric
        colctr = colctr + 1
        sctr = sctr + 1
      end # of 'while sctr < station_num'
      csv << row0

      probevals = Array.new
      probevals = metrichash[stationkeys[0]]
      numentries = probevals.length

      entrynum = 0
      while entrynum < numentries
        row0.clear
        sctr = 0
        t_entry = Time.at(metrichash[stationkeys[sctr]][entrynum][0])
        if t_entry.utc? == false
          t_entry = t_entry.utc
        end # of 't_entry.utc? == false'

        row0[0] = t_entry.to_s
        while sctr < station_num
          if metrichash[stationkeys[sctr]][entrynum][1] == ""
            row0[1+(sctr)] = ""
          else
            row0[1+(sctr)] = metrichash[stationkeys[sctr]][entrynum][1]
          end
          sctr = sctr + 1
        end # of 'while sctr < station_num'
        csv << row0
        entrynum = entrynum + 1
      end # of 'while entrynum < numentries'
    end # of 'CSV.open(fname.to_s, "w") do |csv|'

   return true
  rescue Exception => e
    puts "probedata_to_csv exception ... error is " + e.message + "\n"
    return false
  end
end


# probe_samples
# this routine expects a single probe id,
#   which may contain up to 3 sets of metric keys, with
#   data from up to 5 stations

def probe_samples(_apikey, _id, _probename, _stations, _keys, ts, te, ss)
  begin
    if _stations.is_a?(Array) != true
      puts "\nprobe_samples: invalid parameter: _stations must be an array.\n"
      return nil
    end

    keys = _keys
    keys_array = Array.new
    keys_array = keys.split(",")

    if ss != 0
      easy = Ethon::Easy.new(url: "https://"+_apikey.to_s+":U@api.copperegg.com/v2/revealuptime/samples.json?ids="+_id.to_s+"&keys="+keys.to_s+"&starttime="+ts.to_s+"&endtime="+te.to_s+"&sample_size="+ss.to_s, followlocation: true, verbose: false, ssl_verifypeer: 0, headers: {Accept: "json"}, timeout: 10000)
    else
      easy = Ethon::Easy.new(url: "https://"+_apikey.to_s+":U@api.copperegg.com/v2/revealuptime/samples.json?ids="+_id.to_s+"&keys="+keys.to_s+"&starttime="+ts.to_s+"&endtime="+te.to_s, followlocation: true, verbose: false, ssl_verifypeer: 0, headers: {Accept: "json"}, timeout: 10000)
    end # of 'if ss != 0'
    easy.prepare
    easy.perform

    case easy.response_code
      when 200
        if $verbose == true
          if ss == 0
            puts "Requested data for Probe id "+_id+"; start date " + Time.at(ts).utc.to_s + "; end date " + Time.at(te).utc.to_s+"; default sample size\n"
          else
            puts "Requested data for Probe id "+_id+"; start date " + Time.at(ts).utc.to_s + "; end date " + Time.at(te).utc.to_s+"; sample size "+ ss.to_s+"\n"
          end # of 'if ss == 0'
        end # of 'if $verbose == true'

        if valid_json?(easy.response_body) != true
           puts "\nParse error: Invalid JSON.\n"
          return nil
        end

        probedata = JSON.parse(easy.response_body)
        if probedata.is_a?(Array) != true
          puts "\nParse error: Expected an array.\n"
          return nil
        elsif probedata.length < 1
          puts "\nNo probe data found.\n"
          return nil
        elsif probedata.length != 1
          puts "\nData from more than one probe returned: Internal error.\n"
          return nil
        end

        inp_stations = Array.new
        inp_stations = _stations
        total_station_cnt = inp_stations.length

        oneprobe = Hash.new
        oneprobe = probedata[0]

        if (oneprobe["_ts"] == nil) || (oneprobe["_bs"] == nil)
          if $debug == true
            puts "_ts or _bs was nil. Skipping this probe\n"
          end
        else
          base_time = oneprobe["_ts"]
          sample_time = oneprobe["_bs"]

          if $verbose == true
            puts "Probe data actual start date "+ Time.at(base_time).utc.to_s + "; actual sample size " + sample_time.to_s + "\n"
          end
          if $debug == true
            puts "DEBUG:  top of probe_samples; oneprobe is:\n"
            p oneprobe
            puts "\n"
          end

          incr = sample_time.to_i

          # create a master bucket list for this sample set, to detect missing samples
          buckets = Array.new
          bucketoff = Array.new
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

          # this is the output hash
          probe_hash = Hash.new
          one_keyhash = Hash.new

          station_hash = Hash.new

          # Loop through all metrics sets (keys)
          keys_array.each do |keystr|
            station_hash = oneprobe[keystr]
            if $debug == true
              puts "DEBUG:  station_hash is:\n"
              p station_hash
              puts "\n"
            end

            # Loop through all monitoring stations
            station_hash.each do |_station,_samples|
              samples = Hash.new
              samples = _samples
              if $debug == true
                puts "DEBUG:  samples hash is:\n"
                p _samples
                puts "\n"
              end

              if keystr == "s_u" || keystr == "s_l" || keystr == "s_s"
                missctr = 0
                tmp = Array.new
                arrayctr = 0
                lastsample = 0
                firstsample = -1

                # step through the expected offsets
                while arrayctr < bucketcnt
                  val = samples[bucketoff[arrayctr].to_s]
                  if val == nil
                    tmp[arrayctr] =  [buckets[arrayctr], ""]
                    missctr = missctr + 1
                  else
                    tmp[arrayctr] =  [buckets[arrayctr], val]
                    if firstsample == -1
                      firstsample = arrayctr
                    end
                    lastsample = arrayctr
                    #puts "last sample is "+lastsample.to_s+"\n\t"
                    #p tmp[lastsample]
                  end
                  arrayctr = arrayctr + 1
                end # end of this stations' samples

                missctr = 0
                arrayctr = firstsample
                while arrayctr <= lastsample
                  if tmp[arrayctr] ==  [buckets[arrayctr], ""]
                    missctr = missctr + 1
                  end
                  arrayctr = arrayctr + 1
                end # end of this stations' samples

                # interpolate code here
                if $debug == true
                  puts "Adding station "+stamap(_station.to_s)+":\n"
                  p tmp
                  puts "\n"
                end

                one_keyhash[stamap(_station.to_s)] = tmp

              #elsif keystr == "s_s"

              #elsif keystr == "s_l"
              else
                puts "\nUnsupported metric key.\n"
                return nil
              end
            end  # end of 'station_hash.each do'
            if $debug == true
              puts "Adding metric "+keystr.to_s+":\n"
              p one_keyhash
              puts "\n"
            end

            probe_hash[keystr]=one_keyhash

          end  # end of 'metricskeys.each do'
          if $debug == true
            puts "probe_hash :\n"
            p probe_hash
            puts "\n"
          end
          return probe_hash
        end  # of 'if (oneprobe["_ts"] == nil) || (oneprobe["_bs"] == nil)'
      when 404
        puts "\n HTTP 404 error returned. Aborting ...\n"
      when 500...600
        puts "\n HTTP " +  easy.response_code.to_s +  " error returned. Aborting ...\n"
    end # end of switch on easy.response_code
    return false
  end
end


#
# This is the main portion of the probedata_csvexport.rb utility
#
options = ExportOptions.parse(ARGV,"Usage: probedata_csvexport.rb APIKEY [options]","")

if options != nil
  if $verbose == true
    puts "\nSelected options:\n"
    p options
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

  keys = "s_u,s_s,s_l"

  puts  "Time and Date of this data export: "+trun.to_s+"\n"
  allprobes = Array.new
  allprobes = GetProbes.all($APIKEY)
  if allprobes != nil
    this_probe = Hash.new

    # Loop through each defined probe
    ctr = 0
    while ctr < allprobes.length
      this_probe = allprobes[ctr]

      probehash = probe_samples($APIKEY, this_probe["id"], this_probe["probe_desc"], this_probe["stations"], keys, ts, te, ss)

      # Now loop through each metric specified with keys, and create a csv
      keys_array = Array.new
      keys_array = probehash.keys       # "s_u", "s_l", "s_s"

      keys_array.each do |keystr|
        metric = nil
        case keystr
          when "s_u"
            metric = "Uptime"
          when "s_l"
            metric = "Latency"
          when "s_s"
            metric = "StatusCodes"
        end
        if metric != nil
          probedata_to_csv(probehash[keystr],this_probe["probe_desc"],metric)
        end
      end # of 'keys_array.each do |keystr|'
      ctr = ctr + 1
    end # of 'while ctr < allprobes.length'
  else
    puts "No systems found\n"
  end # of 'if allprobes != nil'
end
