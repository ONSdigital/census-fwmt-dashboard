# frozen_string_literal: true

require 'swagger/diff'

LOCAL_TM_SWAGGER_SPEC = ENV['LOCAL_TM_SWAGGER_SPEC'] || 'https://raw.githubusercontent.com/ONSdigital/census-fwmt-job-service/master/src/main/resources/tm-swagger.json'

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

SCHEDULER.every '30s', first_in: 0 do |_|
  diff = Swagger::Diff::Diff.new(LOCAL_TM_SWAGGER_SPEC, TM_SWAGGER_SPEC)
  msg = diff.compatible? ? 'Compatible' : 'Incompatible'
  send_swagger_status('compare_swagger_files', msg, danger: !diff.compatible?)
rescue StandardError => e
  send_swagger_fatal('compare_swagger_files', e)
  raise e
end
