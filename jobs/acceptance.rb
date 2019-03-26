require 'rubygems'
require 'json'
require "google-cloud-storage"



if !ENV['GCP_DASHBOARD_KEYCONTENTS'].nil?
  File.open("gcs_dashboard_keyfile.json", "w") do |f|
    f.write(ENV['GCP_DASHBOARD_KEYCONTENTS'])
  end
 GCP_DASHBOARD_KEYFILE = 'gcs_dashboard_keyfile.json'
else
  GCP_DASHBOARD_KEYFILE = '../keyfile/gcs_dashboard_keyfile.json'
end

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
SCHEDULER.every '60s', :first_in => 0 do |job|

  storage = Google::Cloud::Storage.new(
    project_id: "census-fwmt-ci-233109",
    credentials: GCP_DASHBOARD_KEYFILE
  )

  bucket = storage.bucket "census-fwmt-acceptance-tests"
  file = bucket.file "cucumber-report.json"

  # Download the file to the local file system
  file.download "public/cucumber-report.json"

  json = File.read('public/cucumber-report.json')
  parsed = JSON.parse(json)

  event_count = 1
  parsed[0]['elements'].each do |element|
    scenario = element['name']
    step_name = 'Steps Pass'
    error = 'OK'
    scenario_status = 'OK'
    element['steps'].each do |test_element|
      status = test_element['result']['status']
      if status == 'failed'
        step_name = test_element['name']
        error = test_element['result']['error_message']
        scenario_status = status
      end
    end
    send_event('cucumber_status_' + event_count.to_s, { status: scenario_status, scenario: scenario, step: step_name, error: error.slice(0..100)})
    event_count += 1
  end
end
