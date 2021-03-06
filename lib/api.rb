#!/usr/bin/env ruby
# Copyright 2012,2013 IDERA.  All rights reserved.
#
# encoding: utf-8

require 'ethon'

class GetSystems
  def self.all(apikey)
    url = "https://#{apikey}:U@api.copperegg.com/v2/revealcloud/systems.json"
    return httpget(apikey, url, {})
  end
end


class GetProbes
  def self.all(apikey)
    url = "https://#{apikey}:U@api.copperegg.com/v2/revealuptime/probes.json"
    return httpget(apikey, url, {})

  end
end

class GetIssues
  def self.all(apikey, ts, te, per_page, page_number)
    url = "https://#{apikey}:U@api.copperegg.com/v2/alerts/issues.json?begin_time=#{ts}&end_time=" +
          "#{te}&per_page=#{per_page}&page_number=#{page_number}"
    return httpget(apikey, url, {})
  end
end

class GetSystemSamples
  def self.uuid(_apikey, _uuid, _keys, ts, te, ss)
    keys = _keys
    url = "https://#{_apikey}:U@api.copperegg.com/v2/revealcloud/samples.json?uuids=#{_uuid}&keys=#{keys}&starttime=" +
          "#{ts}&endtime=#{te}"
    if ss != 0
      url = "#{ur}l&sample_size=#{ss}"
    end
    return httpget(_apikey, url, {})
  end
end

class GetProbeSamples
  def self.probeid(_apikey, _id, _keys, ts, te, ss)
    keys = _keys
    url = "https://#{_apikey}:U@api.copperegg.com/v2/revealuptime/samples.json?ids=#{_id}&keys=#{keys}&starttime=" +
          "#{ts}&endtime=#{te}"
    if ss != 0
      url = "#{ur}l&sample_size=#{ss}"
    end
    return httpget(_apikey, url, {})
  end
end

def valid_json? json_
  begin
    JSON.parse(json_)
  rescue Exception => e
    return nil
  end
end

def httpget(apikey,url,params)
  attempts = 3
  exception_try_count = 0
  connect_try_count = 0
  do_verbose = false

  puts "url is " + url.to_s + "\n"
  easy = Ethon::Easy.new

  while connect_try_count < attempts
    begin
      easy.http_request( url, :get, {
       headers: {'Accept' => 'application/json','Content-Type' => 'application/json'},
       ssl_verifypeer: false,
       followlocation: true,
       verbose: do_verbose,
       timeout: $Max_Timeout
       } )
      easy.perform

      case easy.response_code
      when 0
        if $verbose == true
          puts "\nGet API call timed-out\n"
        end
      when 200
        probedata = valid_json?(easy.response_body)
        if probedata == nil
           puts "\nGet Parse error: Invalid JSON received.\n"
          return nil
        end

       if probedata.is_a?(Array) != true
          puts "\nGet Expected an array.\n"
          return nil
        elsif probedata.length < 1
          puts "\nGet No data found.\n"
          return nil
        end
        return probedata
      else
        if $verbose == true
          puts "\nGet: HTTP error returned: " + easy.response_body.to_s + "\n"
        end
      end
    rescue Exception => e
      exception_try_count += 1
      if exception_try_count > attempts
        raise e
        if $verbose == true
          puts "\nGet: exceeded retries\n"
        end
        return nil
      end
      if $verbose == true
        puts "\nGet: exception: retrying\n"
      end
      sleep 0.5
    retry
    end
    connect_try_count += 1
    if $verbose == true
      puts "Retrying\n"
    end
    sleep 0.5
  end
end
