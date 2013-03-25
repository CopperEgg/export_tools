#!/usr/bin/env ruby
# Copyright 2012 CopperEgg Corporation.  All rights reserved.
#
# sysinfo_csvexport.rb is a utility to export system information from CopperEgg to csv.
#
#
#encoding: utf-8

require 'rubygems'
require "json/pure"
require 'csv'
#require 'FileUtils'
require './lib/ver'
require './lib/exportoptions'
require './lib/api'
require './lib/filters'

$output_path = "."
$APIKEY = ""
$outpath_setup = false
$verbose = false
$debug = false
$Max_Timeout = 120

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
    else
      @str = '???'
  end
  return @str
end

def sysinfo_to_csv(allsystems)
  begin
    if $debug == true
      puts "At start of sysinfo_to_csv and output path is "+$output_path.to_s+"\n"
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
    fname = $output_path.to_s+"/allsystems.csv"
    if $verbose == true
      puts "Writing to "+fname.to_s+"\n\n"
    end
    CSV.open(fname.to_s, "wb") do |csv|

      num_systems = allsystems.length

      row0 = Array.new
      row0 = ["uuid", "hidden", "hostname",	"tags",	"OS",	"OS version",	"collector verison",	"Create Date UTC",	"Last Update UTC", "Created at",	"Last updated",	"health index",	"summary state",	"uptime state",	"blocked state",	"load state",	"cpu state",	"memory state",	"filesystems state" ]
      csv << row0

      ctr = 0
      sys = Hash.new
      attr = Hash.new
      while ctr < num_systems
        row0.clear
        sys = allsystems[ctr]
        #p sys
        attr = sys["a"]
        #p attr
        os = nil
        case attr["o"]
          when 'm'
            os = 'Mac OS X'
          when 'l'
            os = 'Linux'
          when 'w'
            os = 'Microsoft Windows'
          when 'f'
            os = 'FreeBSD'
        end
        if os == nil
          puts "Unrecognized OS: "+attr["o"]+"\n"
          os = "???"
        end

        row0 = [ sys["uuid"].to_s, sys["hid"],  attr["n"], attr["t"], os.to_s, attr["ov"].to_s, attr["rv"].to_s,
                  Time.at(attr["c"]).utc, Time.at(attr["p"]).utc, attr["c"], attr["p"], attr["h"], state_to_s(attr["s"]),
                  state_to_s(attr["us"]), state_to_s(attr["bs"]), state_to_s(attr["ls"]), state_to_s(attr["cs"]),
                  state_to_s(attr["ms"]), state_to_s(attr["fs"])]
        csv << row0
        sys.clear
        attr.clear
        ctr = ctr + 1
      end # of 'while ctr < num_systems'
    end # of 'CSV.open(fname.to_s, "w") do |csv|'
    return true
  rescue Exception => e
    puts "sysinfo_to_csv exception ... error is " + e.message + "\n"
    return false
  end
end

#
# This is the main portion of the sysinfo_csvexport.rb utility
#

options = ExportOptions.parse(ARGV,"Usage: sysinfo_csvexport.rb APIKEY [options]","")
puts $VersionString

if options != nil
  tr = Time.now
  trun = Time.new(tr.year,tr.month,tr.day,tr.hour,tr.min,tr.sec)

  puts  "Time and Date of this data export: "+trun.to_s+"\n"
  numberlive = 0
  allsystems = Array.new
  allsystems = GetSystems.all($APIKEY)

  if allsystems != nil
    sysinfo_to_csv(allsystems)
  else
    puts "No systems found\n"
  end # of 'if allsystems != nil'
end