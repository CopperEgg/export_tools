export_tools
=============

Ruby scripts for extracting your CopperEgg data to CSV files.

###Synopsis
Four utilities are provided:

  - probeinfo_csvexport.rb.....all probe information (definition and configuration) for all of your monitored RevealUptime probes is retrieved and exported to CSV.

  - sysinfo_csvexport.rb.......all system information (definition and configuration) for all of your monitored RevealCloud systems is retrieved and exported to CSV.

  - probedata_csvexport.rb.....historical data gathered from your probes is retrieved and exported to CSV.

  - sysdata_csvexport.rb.......historical data gathered from your systems is retrieved and exported to CSV.

These ruby scripts and associated library scripts are based on :
* ruby-1.9.3
* The CopperEgg API
* Ethon

All development and testing to date has been done with ruby-1.9.3.

* [CopperEgg API](http://dev.copperegg.com/)
* [typhoeus/ethon](https://github.com/typhoeus/ethon)

## Recent Updates
* version 1.1.1 released 2-2-2014
  - added retries to HTTP GET requests in api.rb

* version 1.1.0 released 3-25-2013
  - added more time interval options
  - changed interface to local time
  - added support for selecting systems or probes by tag
  - added support for exporting processes
  - all metrics from a system or probe are exported to a single CSV
  - generally improved stability.

## Installation

###Clone this repository.

```ruby
git clone https://github.com/CopperEgg/export_tools.git
```

###Run the Bundler

```ruby
bundle
```

## Usage

```ruby
ruby sysinfo_csvexport.rb APIKEY [options]
```
Substitute APIKEY with your CopperEgg User API key. Find it as follows:
Settings tab -> Personal Settings -> User API Access

Your command line will appear as follows:

```ruby
ruby sysinfo_csvexport.rb '1234567890123456'
```

## Defaults and Options

The available options can be found by typing in the following on your command line
```ruby
ruby sysinfo_csvexport.rb -h
```

Today these options are

* -o, --output_path                Path to write .csv files
* -s, --sample_size [SECONDS]      Override default sample size
* -i, --interval [INTERVAL]        Select interval (ytd, pcm, mtd,...)
* -v, --verbose                    Run verbosely
* -h, --help                       See complete list and description of command line options

* -o, --outputpath [PATH]          Path to write CSV files
* -u, --UUID [IDENTIFIER]          The UUID of the system or probe whose data to export.
                                     Should not be used wth the -t option.
* -t, --tagstring [TAG]            Return data from the systems or probes with this tag.
                                     If not entered, data from all systems / probes will be exported.
* -i, --interval [INTERVAL]        Select interval (ytd, pcm, mtd, last1d, last7d, last30d, last60d, last90d, last6m, last12m)
                                      ytd (year-to-date), pcm (previous calendar month), lastXd (last x days)
* -b, --begin [DATE]               Begin time of exported data. %Y-%m-%d %H:%M
                                     For example, -b 2013-1-1 00:00  Your entry should be in you local time
                                     Use this option along with the -e End option. Cannot use this option if -i option is used.
* -e, --end [DATE]                 End time of exported data. %Y-%m-%d %H:%M
                                     For example, -e 2013-3-1 00:00  Your entry should be in you local time
                                     Use this option along with the -b option. Cannot use this option if -i option is used.
* -s, --sample_size [SECONDS]      Override default sample size
*     --metrics x,y,z              Specify list of individual metrics
                                     h,r,b,l,m,s,c,n,d,f,p default is all
                                     h (health), r (running procs), b (blocked procs), l (load), m (memory)
                                     s (swap), c (cpu), n (network io), d (disk io), f (filesystems), p (processes)
* -v, --verbose                    Run verbosely
* -d, --debug                      Run with debug output

* -h, --help                       Show this message


### Output Path
The CSV file will be written to the current directory ("./"), with the filename 'hostname.csv' or 'probename.csv'.

To override the destination path, use the -o option. An example follows:

```ruby
ruby sysinfo_csvexport.rb '1234567890123456' -o 'cuegg-data-20121001'
```
In this example, all files will be written to the 'cuegg-data-20121001' subdirectory of the current directory. If the specified destination directory does not exist, it will be created.

### Sample Size
The 'sample size' refers to the interval over which each data point is averaged. The sample size in realtime operation is 5 seconds.

The sample size of the data returned by the API is a function of the range of time requested. Using the default time interval (which is the past 24 hours), the default sample size is 300 seconds, or 5 minutes.If you select a longer time interval, (for example, year-to-date), the sample size will be as long as 1 day.
 * Note that you cannot select a sample time less than the sample time returned from the API by default. To shorten the time sample length, you need to request data from a shorter time interval.

In the following example, the data from the past 24 hours is exported as a series of 5 minute samples

```ruby
ruby sysdata_csvexport.rb '1234567890123456' -o 'sysdata-20121001'
```

### Time Interval
Specify the interval over which to export data. The default (no option specified) is to export the data from the previous 24 hours.
To specify other time intervals, you can select one of the following shortcuts using the '-i' option:
* ytd   year to date
* pcm   previous calendar month
* mtd   month to date
* last7d, last30d, last60d, last90d
* last6m  last 6 months
* last12m last 12 months

In the following example, the data from the beginning of the current calendar year until now is exported

```ruby
ruby sysdata_csvexport.rb '1234567890123456' -o 'sysdata-20121001' -i 'ytd'
```

You can also specify the data export time interval with more granularity using the 'begin' and 'end' options instead of the 'interval' option. The begin and end times are specified in local time, as follows:
* -b YYYY-M-D HH:MM   for example, 2013-1-1 00:00
* -e YYYY-M-D HH:MM   for example, 2013-2-1 00:00

In the following example, the data from Jan 1, 2013 through February 1, 2013 will be exported

```ruby
ruby sysdata_csvexport.rb '1234567890123456' -o 'sysdata-20121001' -b '2013-1-1 00:00' -e '2013-2-1 00:00'
```

### Verbosity
To see what is happening as the script is running, include the -v option.


### CSV files

One CSV file is created for all metrics specified, for each system or probe monitored during the time interval exported.


##  LICENSE

(The MIT License)

Copyright © 2012, 2013 [CopperEgg Corporation](http://copperegg.com)

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without
limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons
to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
