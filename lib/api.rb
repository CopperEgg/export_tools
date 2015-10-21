#!/usr/bin/env ruby
# Copyright 2012,2013 IDERA.  All rights reserved.
#
#
#encoding: utf-8

require 'ethon'


class GetSystems
  def self.all(apikey)
    url = "https://"+apikey.to_s+":U@api.copperegg.com/v2/revealcloud/systems.json"
    return httpget(apikey,url,{})
  end
end  #  of class


class GetProbes
  def self.all(apikey)
    url = "https://"+apikey.to_s+":U@api.copperegg.com/v2/revealuptime/probes.json"
    return httpget(apikey,url,{})

  end
end  #  of class

class GetIssues
  def self.all(apikey,ts,te)
    url = "https://"+apikey.to_s+":U@api.copperegg.com/v2/alerts/issues.json?begin_time="+ts.to_s+"&end_time="+te.to_s
    return httpget(apikey,url,{})
  end
end  #  of class

class GetSystemSamples
  def self.uuid(_apikey, _uuid, _keys, ts, te, ss)
    keys = _keys
    url = "https://"+_apikey.to_s+":U@api.copperegg.com/v2/revealcloud/samples.json?uuids="+_uuid.to_s+"&keys="+keys.to_s+"&starttime="+ts.to_s+"&endtime="+te.to_s
    if ss != 0
      url = url+ "&sample_size="+ss.to_s
    end
    return httpget(_apikey,url,{})
  end
end  #  of class

class GetProbeSamples
  def self.probeid(_apikey, _id, _keys, ts, te, ss)
    keys = _keys
    url = "https://"+_apikey.to_s+":U@api.copperegg.com/v2/revealuptime/samples.json?ids="+_id.to_s+"&keys="+keys.to_s+"&starttime="+ts.to_s+"&endtime="+te.to_s
    if ss != 0
      url = url + "&sample_size="+ss.to_s
    end
    return httpget(_apikey,url,{})
  end
end  #  of class

def valid_json? json_
  begin
    JSON.parse(json_)
  rescue Exception => e
    return nil
  end
end
# now with ethon!

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
         :headers => {"Accept" => "application/json","Content-Type" => "application/json"},
         :ssl_verifypeer => false,
         :followlocation => true,
         :verbose => do_verbose,
         :timeout => $Max_Timeout
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
          puts "\nGet: HTTP error returned: " + easy.response_code.to_s + "\n"
        end
        #return nil
      end # of switch statement
    rescue Exception => e
      exception_try_count += 1
      if exception_try_count > attempts
        #log "#{e.inspect}"
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
    end  # of begin rescue end
    connect_try_count += 1
    if $verbose == true
      puts "Retrying\n"
    end
    sleep 0.5
  end # of while connect_try_count < attempts
end  #  of httpget
