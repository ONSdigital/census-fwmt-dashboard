require 'rubygems'
require 'json'

REPORT_FILE          = ENV['REPORT_FILE'] || 'cucumber-report.json'
REPORT_FILE_LOCATION = ENV['REPORT_FILE_LOCATION'] || 'http://localhost:9292'

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
SCHEDULER.every '5s', :first_in => 0 do |job|

  #json = File.read('cucumber-report.json')
  parsed = JSON.parse(HTTParty.get(REPORT_FILE_LOCATION+"/"+REPORT_FILE).body)

  event_count = 1
  parsed[0]['elements'].each do |element|
    status = element['before'][0]['result']['status']
    scenario = ''
    error = ''
    if status == 'failed'
      scenario = element['name']
      error = element['before'][0]['result']['error_message']
    else
      scenario = element['name']
      error = "OK"
    end
    send_event('cucumber_status_' + event_count.to_s, { status: status, scenario: scenario, error: error.slice(0..100)})

    event_count += 1
  end
end
