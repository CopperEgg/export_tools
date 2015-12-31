require 'rubygems'
require 'json/pure'
require 'csv'
require './lib/ver'
require './lib/exportoptions'
require './lib/api'

$output_path = "."
$file_name=""
$verbose = false
$debug = false
$t_start = 0
$t_end = 0

def format_row(row)
  row.delete("attr_description")
  row.delete("obj_idv")
  row["short_msg"] = row["short_msg"].gsub(',','_')
  row["created_at"] = row["created_at"]==0 ? " ": Time.at(row["created_at"])
  row["updated_at"] = row["updated_at"]==0 ? " ": Time.at(row["updated_at"])
  row["cleared_at"] = row["cleared_at"]==0 ? " ": Time.at(row["cleared_at"])
  row["notified_at"] = row["notified_at"]==0 ? " ": Time.at(row["notified_at"])
  row.values
end

def issues_to_csv(issues_json)
  begin
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
        else  # $verbose is off
          if Dir.mkdir($output_path.to_s+"/",0775) == -1
            print "FAILED to create directiory "+$output_path.to_s+"/"+"\n"
            return false
          else
            FileUtils.chmod 0775, $output_path.to_s+"/"
          end
        end
      else
        FileUtils.chmod 0775, $output_path.to_s+"/"
      end
    end

    if $verbose
      puts "Generating CSV, #{issues_json.length} rows in total."
    end

    #begining csv generation
    $file_name = $output_path.to_s+"/"+"issues "+$t_start.to_s.gsub(':','_')+" "+$t_end.to_s.gsub(':','_')+".csv"
    headers = ["ID","State","Short Message","Additional Information","Type","Created At","Updated At","Cleared At","Notified At",
               "Ignore Until", "Annotation Id","Group Def Id"]
    CSV.open($file_name.to_s, "wb",:write_headers => true,
             :headers => headers) do |csv|
      ctr = 0
      while ctr < issues_json.length
        csv << format_row(issues_json[ctr])
        ctr += 1
      end
    end
  rescue Exception => e
    puts "Error in generating CSV. "
    if $debug
      puts "Error : #{e.message}"
    end
  end
end
options = ExportOptions.parse(ARGV,"Usage: issue_csvexport.rb APIKEY [options]","issue")
puts $VersionString

$t_start = Time.new(options.start_year,options.start_month,options.start_day,options.start_hour,options.start_min,options.start_sec)
$t_end = Time.new(options.end_year,options.end_month,options.end_day,options.end_hour,options.end_min,options.end_sec)

issues = GetIssues.all($APIKEY, $t_start.utc.to_i, $t_end.utc.to_i, options.per_page, options.page_number)

unless issues == nil
  issues_to_csv(issues)
  if $verbose
    puts "CSV saved to #{$file_name}"
  end
else
  puts "No issues were found in given interval or the API key was invalid. No CSV was generated"
end

