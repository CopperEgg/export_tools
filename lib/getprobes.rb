#!/usr/bin/env ruby
# Copyright 2012 CopperEgg Corporation.  All rights reserved.
#
# getprobes.rb contains classes to retrieve all probe information for a CopperEgg site.
#
#
#encoding: utf-8

require 'json'
require 'typhoeus'

class GetProbes
  def self.all(apikey)
    begin
      easy = Ethon::Easy.new(url: "https://"+apikey.to_s+":U@api.copperegg.com/v2/revealuptime/probes.json", followlocation: true, verbose: false, ssl_verifypeer: 0, headers: {Accept: "json"}, timeout: 10000)
      easy.prepare
      easy.perform

      number_probes = 0
      all_probes = Array.new

      case easy.response_code
        when 200
          if valid_json?(easy.response_body) == true
            record = JSON.parse(easy.response_body)
            if record.is_a?(Array)
              number_probes = record.length
              if number_probes > 0
                return record
              else # no probes found
                puts "\nNo probes found at this site. Aborting ...\n"
                return nil
              end # of 'if number_probes > 0'
            else # record is not an array
              puts "\nParse error: Expected an array. Aborting ...\n"
              return nil
            end # of 'if record.is_a?(Array)'
          else # not valid json
            puts "\nGetProbes: parse error: Invalid JSON. Aborting ...\n"
            return nil
          end # of 'if valid_json?(easy.response_body)'
        when 404
          puts "\nGetProbes: HTTP 404 error returned. Aborting ...\n"
          return nil
        when 500...600
          puts "\nGetProbes: HTTP " +  easy.response_code.to_s +  " error returned. Aborting ...\n"
          return nil
      end # of switch statement
    rescue Exception => e
      puts "Rescued in GetProbes:\n"
      p e
      return nil
    end  # of begin rescue end
  end  # of 'def self.all(apikey)'
end  #  of class