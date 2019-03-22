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
