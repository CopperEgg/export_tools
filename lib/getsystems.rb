#!/usr/bin/env ruby
# Copyright 2012 CopperEgg Corporation.  All rights reserved.
#
# getsystems.rb contains classes to retrieve all system information for a CopperEgg site.
#
#
#encoding: utf-8

require 'json'
require 'typhoeus'

class GetSystems
  def self.all(apikey)
    begin
      easy = Ethon::Easy.new(url: "https://"+apikey.to_s+":U@api.copperegg.com/v2/revealcloud/systems.json", followlocation: true, verbose: false, ssl_verifypeer: 0, headers: {Accept: "json"}, timeout: 10000)
      easy.prepare
      easy.perform

      number_systems = 0
      all_systems = Array.new

      case easy.response_code
        when 200
          if valid_json?(easy.response_body) == true
            record = JSON.parse(easy.response_body)
            if record.is_a?(Array)
              number_systems = record.length
              if number_systems > 0
                return record
              else # no systems found
                puts "\nNo systems found at this site. Aborting ...\n"
                return nil
              end # of 'if number_systems > 0'
            else # record is not an array
              puts "\nParse error: Expected an array. Aborting ...\n"
              return nil
            end # of 'if record.is_a?(Array)'
          else # not valid json
            puts "\nGetSystems: parse error: Invalid JSON. Aborting ...\n"
            return nil
          end # of 'if valid_json?(easy.response_body)'
        when 404
          puts "\nGetSystems: HTTP 404 error returned. Aborting ...\n"
          return nil
        when 500...600
          puts "\nGetSystems: HTTP " +  easy.response_code.to_s +  " error returned. Aborting ...\n"
          return nil
      end # of switch statement
    rescue Exception => e
      puts "Rescued in GetSystems:\n"
      p e
      return nil
    end
  end
end

