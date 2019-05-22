# frozen_string_literal: true

require 'rubygems'
require 'json'
require 'google/cloud/storage'

if !ENV['GCP_DASHBOARD_KEYCONTENTS'].nil?
  File.open('gcs_dashboard_keyfile.json', 'w') do |f|
    f.write(ENV['GCP_DASHBOARD_KEYCONTENTS'])
  end
  GCP_DASHBOARD_KEYFILE = 'gcs_dashboard_keyfile.json'
else
  GCP_DASHBOARD_KEYFILE = '../keyfile/gcs_dashboard_keyfile.json'
end

def send_pass_event(id, scenario_element)
  send_event(id,
             status: 'OK',
             scenario: scenario_element['name'],
             step: 'Steps Pass',
             error: 'OK')
end

def send_fail_scenario_event(id, scenario_element)
  result = scenario_element['before'][0]['result']
  send_event(id,
             status: result['status'],
             scenario: scenario_element['name'],
             step: 'no steps run',
             error: result['error_message'].slice(0..60))
end

def send_fail_test_event(id, scenario_element, test_element)
  send_event(id,
             status: test_element['result']['status'],
             scenario: scenario_element['name'],
             step: test_element['name'],
             error: test_element['result']['error_message'].slice(0..60))
end

def send_fatal_event(id)
  send_event(id,
             status: 'Fatal Error',
             scenario: 'Unknown',
             step: 'Fatal Error',
             error: 'Inspect Log',
             fatal: true)
end

def fetch_report
  storage = Google::Cloud::Storage.new(
    project_id: 'census-fwmt-ci-233109',
    credentials: GCP_DASHBOARD_KEYFILE
  )

  bucket = storage.bucket 'census-fwmt-acceptance-tests'
  file = bucket.file 'cucumber-report.json'

  # Download the file to the local file system
  file.download 'public/reports/cucumber-report.json'

  JSON.parse(File.read('public/reports/cucumber-report.json'))
end

SCHEDULER.every '60s', first_in: 0 do |_|
  report = fetch_report
  report[0]['elements'].each_with_index do |element, index|
    id = "cucumber_status_#{index + 1}"
    begin
      if element['before'][0]['result']['status'] == 'failed'
        send_fail_scenario_event(id, element)
        break
      else
        element['steps'].each do |test_element|
          if test_element['result']['status'] == 'failed'
            send_fail_test_event(id, element, test_element)
            break
          end
        end
      end
      send_pass_event(id, element)
    rescue StandardError
      send_fatal_event(id)
      raise
    end
  end
end
