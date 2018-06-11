#!/usr/bin/env ruby
# Copyright 2012 IDERA.  All rights reserved.
#
# probeinfo_csvexport.rb is a utility to export probe information from Uptime Cloud Monitor to csv.
#
# encoding: utf-8

require 'rubygems'
require 'json/pure'
require 'csv'
require './lib/ver'
require './lib/exportoptions'
require './lib/api'
require './lib/filters'

$output_path = '.'
$APIKEY = ''
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

def nonil _this
  if _this.nil?
    return ""
  else
    return _this
  end
end

def probeinfo_to_csv(allprobes)
  begin
    if $debug == true
      puts "At start of probeinfo_to_csv and output path is #{$output_path}\n"
    end
    if $outpath_setup == false
      $outpath_setup = true
      if $output_path != "."
        if Dir.exists?("#{$output_path}/") == false
          if $verbose == true
            print 'Creating directory...'
            if Dir.mkdir("#{$output_path}/", 0775) == -1
              print "** FAILED ***\n"
              return false
            else
              FileUtils.chmod(0775, "#{$output_path}/")
              print "Success\n"
            end
          else
            if Dir.mkdir("#{$output_path}/" , 0775) == -1
              print "FAILED to create directiory #{$output_path}/\n"
              return false
            else
              FileUtils.chmod(0775, "#{$output_path}/")
            end
          end
        else
          FileUtils.chmod(0775, "#{$output_path}/")
       end #
      end
    end
    fname = "#{$output_path}allprobes.csv"
    if $verbose == true
      puts "Writing to #{fname}\n\n"
    end
    CSV.open(fname, 'wb') do |csv|
      num_probes = allprobes.length

      row0 = Array.new
      row0 = ['id', 'status', 'description',	'url', 'tags', 'type', 'data', 'check contents',
              'content match', 'interval', 'Probe created UTC',	'Probe last updated UTC',
              'Probe created (epoch)',	'Probe last updated (epoch)', 'stations', 'timeout (ms)', 'retries']
      csv << row0

      ctr = 0
      sys = Hash.new
      attr = Hash.new
      while ctr < num_probes
        row0.clear
        sys = allprobes[ctr]
        row0 = [sys['id'].to_s, sys['state'], sys['probe_desc'], sys['probe_dest'], sys['tags'],
                sys['type'], nonil(sys['data']), sys['checkcontents'], nonil(sys['contentmatch']), sys['frequency'],
                Time.at(sys['created_at']).utc, Time.at(sys['updated_at']).utc, sys['created_at'], sys['updated_at'],
                sys['stations'], sys['timeout'], sys['retries']]

        csv << row0
        sys.clear
        attr.clear
        ctr = ctr + 1
      end
    end
    return true
  rescue Exception => e
    puts "probeinfo_to_csv exception ... error is #{e.message}\n"
    return false
  end
end

options = ExportOptions.parse(ARGV, 'Usage: probeinfo_csvexport.rb APIKEY [options]', '')
puts $VersionString

if options != nil
  tr = Time.now
  trun = Time.new(tr.year, tr.month, tr.day, tr.hour, tr.min, tr.sec)

  puts  "Time and Date of this data export: #{trun}\n"
  numberlive = 0
  allprobes = Array.new
  allprobes = GetProbes.all($APIKEY)

  if allprobes != nil
    probeinfo_to_csv(allprobes)
  else
    puts "No probes found\n"
  end
end
