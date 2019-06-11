# frozen_string_literal: true

require 'swagger/diff'
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

TM_HOSTNAME = ENV['TM_HOSTNAME'] || 'tm'
TM_PORT = ENV['TM_PORT'] || '80'
TM_SWAGGER_SPEC = ENV['TM_SWAGGER_SPEC'] ||
                  "http://#{TM_HOSTNAME}:#{TM_PORT}/swagger/v1/swagger.json"

def send_swagger_status(id, text, **options)
  defaults = { moreinfo: '', warning: false, danger: false, fatal: false }
  send_event(id, text: text, **defaults.merge(options))
end

def send_swagger_fatal(id, exception)
  send_swagger_status(id, 'Fatal Error',
                      moreinfo: exception.message, fatal: true)
end

def fetch_swagger
  storage = Google::Cloud::Storage.new(
    project_id: 'census-fwmt-ci-233109',
    credentials: GCP_DASHBOARD_KEYFILE
  )

  bucket = storage.bucket 'census-fwmt-acceptance-tests'
  file = bucket.file 'tm-swagger.json'

  # Download the file to the local file system
  file.download 'public/swagger/tm-swagger.json'

  JSON.parse(File.read('public/swagger/tm-swagger.json'))
end

SCHEDULER.every '30s', first_in: 0 do |_|
  local_json = fetch_swagger
  diff = Swagger::Diff::Diff.new(local_json, TM_SWAGGER_SPEC)
  msg = diff.compatible? ? 'Compatible' : 'Incompatible'
  send_swagger_status('compare_swagger_files', msg, danger: !diff.compatible?)
rescue StandardError => e
  send_swagger_fatal('compare_swagger_files', e)
  raise e
end
