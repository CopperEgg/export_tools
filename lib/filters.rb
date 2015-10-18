#!/usr/bin/env ruby
# Copyright 2012,2013 IDERA.  All rights reserved.
#
#
#encoding: utf-8

def systemsfilter_bytag(systems,tag)
  begin
    num_systems = systems.length
    numwithtag = 0
    withtag = Array.new
    num = 0
    while num < num_systems
      h = systems[num]
      if (h["uuid"] != nil) && (h["hid"] == 0)
        ha = h["a"]
        if ha["t"] != nil
          if ha["t"].include?(tag)
            withtag[numwithtag] = h
            numwithtag = numwithtag + 1
          end
        end
      end
      num = num + 1
    end
    return withtag
  rescue Exception => e
    puts "\nsystemsfilter_bytag exception ... error is " + e.message + "\n"
    return nil
  end
end


def systemsfilter_byuuid(systems,uuid)
  begin
    num_systems = systems.length
    array = Array.new
    foundit = 0

    num = 0
    while num < num_systems
      h = systems[num]
      if (h["uuid"] == uuid) && (h["hid"] == 0)
        array[0] = h
        return array
      end
      num = num + 1
    end
    return []
  rescue Exception => e
    puts "\nsystemsfilter_byuuid exception ... error is " + e.message + "\n"
    return nil
  end
end

def probesfilter_bytag(probes,tag)
  begin
    num_probes = probes.length
    numwithtag = 0
    withtag = Array.new
    num = 0
    while num < num_probes
      h = probes[num]
      if h["id"] != nil
        ht = h["tags"]
        if ht != nil
          if ht.include?(tag)
            withtag[numwithtag] = h
            numwithtag = numwithtag + 1
          end
        end
      end
      num = num + 1
    end
    return withtag
  rescue Exception => e
    puts "\nprobesfilter_bytag exception ... error is " + e.message + "\n"
    return nil
  end
end

def probesfilter_byid(probes,id)
  begin
    num_probes = probes.length
    array = Array.new
    num = 0
    while num < num_probes
      h = probes[num]
      if h["id"] == id
        array[0] = h
        return array
      end
      num = num + 1
    end
    return []
  rescue Exception => e
    puts "\nprobesfilter_byid exception ... error is " + e.message + "\n"
    return nil
  end
end


