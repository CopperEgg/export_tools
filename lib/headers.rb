#!/usr/bin/env ruby
# Copyright 2012,2013 IDERA.  All rights reserved.
#
# sysdata_export.rb is a utility to export system data from Uptime Cloud Monitor to csv.
#
# encoding: utf-8


class CSVHeaders
  def self.create(type,sample_cats,names,first)
    begin
      row = Array.new
      if first
        row[0] = 'Date & Time (local)'
        rowindex = 1
      else
        rowindex = 0
      end

      case type
      when 'simple'
        # handle the simple headers
        sample_cats.each do |cat|
          row[rowindex] = cat
          rowindex = rowindex + 1
        end
      when 'complex'
        # handle the more complex headers
        names.each do |n|
          sample_cats.each do |c|
            row[rowindex] = n + "  " + c
            rowindex = rowindex + 1
          end
        end
      else
        puts "Create-headers: internal error\n"
        return nil
      end
      return row
    end
  end
end
