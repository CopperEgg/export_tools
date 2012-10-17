#!/usr/bin/env ruby
# Copyright 2012 CopperEgg Corporation.  All rights reserved.
#
# sysdata_export.rb is a utility to export system data from CopperEgg to csv.
#
#
#encoding: utf-8


# inp_keyhash can be any of the following for system data:
# The first group is fixed
#   keystr "h"  inp_keyhash {"0":[1.0,1,1,1,1,1,1,1,1.0,1],"60":[1.0,1,1,1,1,1,1,1,1.0,1], etc..}
#   keystr "r"  inp_keyhash {"0":2,"60":2,"120":2}
#   keystr "b:  inp_keyhash {"0":2,"60":2,"120":2}
#   keystr "l:  inp_keyhash {"0":0.6,"60":0.9,"120":1.0}
#   keystr "m"  inp_keyhash {"0":[104.91,526.57,922.87,102.85],"60":[104.91,526.57,922.87,102.85], etc...}
#   keystr "s:  inp_keyhash {"0":[0.0,895.0],"60":[0.0,895.0], etc...}
#
# The followoing groups are variable
#   keystr "s_c":
#                inp_keyhash { {"cpu0":{"0":[0.003,0.0,0.0015,0.0,0.001,0.0,0.0005,0.0,0.0],etc...},
#                              {"cpu1":{"0":[0.003,0.0,0.0015,0.0,0.001,0.0,0.0005,0.0,0.0],etc...}
#
#   keystr "s_i":
#               inp_keyhash { {"eth0":"0":[0.0012,0.0004],"60":[0.0012,0.0004],etc...},
#                             {"eth1":"0":[0.0012,0.0004],"60":[0.0012,0.0004],etc...} }
#
#   keystr "s_f":
#               inp_keyhash { {"/": "0":[1160.87,6820.66],"60":[1160.87,6820.66], etc...},
#                             {"/home": "0":[1160.87,6820.66],"60":[1160.87,6820.66], etc...}
#
#   keystr "s_d":
#               inp_keyhash { {"xvda1": "0":[0.0,0.0],"60":[0.0,0.0], etc...},
#                             {"xvda3": "0":[1160.87,6820.66],"60":[1160.87,6820.66], etc...}
#
#   keystr "p":
#               inp_keyhash {
#                 \"p\":[
#                     [\"System\", null,null,null,\"-\",0,0.000125,0.000125,76,25022464,1679360,0],
#                     [\"udevd\",null,384,\"0\",\"-\",0,0,0,8,65806336,2572288,0]
#                 ],
#                 \"u\":[
#                     [0,0.015250,0.024250,0.039500,141,3216269312,1129074688,0],
#                     [999,0.001750,0.006375,0.008125,15,1016483840,5582848,0]
#                 ]
#               }
#

class CSVHeaders

  def self.create(sample_cats,names)
    begin
      row = Array.new
      row[0] = "Date & Time UTC"
      rowindex = 1

      if sample_cats == nil || (sample_cats.empty? == true)
        puts "Create-headers: internal error\n"
        return nil
      end

      if names == nil || (names.empty? == true)
        # handle the simple headers
        sample_cats.each do |cat|
          row[rowindex] = cat
          rowindex = rowindex + 1
        end
      else
        # handle the more complex headers
        names.each do |n|
          sample_cats.each do |c|
            row[rowindex] = n + "  " + c
            rowindex = rowindex + 1
          end
        end
      end
      return row
    end
  end
end
