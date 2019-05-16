# frozen_string_literal: true

require 'swagger/diff'

LOCAL_TM_SWAGGER_SPEC = ENV['LOCAL_TM_SWAGGER_SPEC'] || 'https://raw.githubusercontent.com/ONSdigital/census-fwmt-job-service/master/src/main/resources/tm-swagger.json'

TM_HOSTNAME = ENV['TM_HOSTNAME'] || 'tm'
TM_PORT = ENV['TM_PORT'] || '80'
TM_SWAGGER_SPEC = ENV['TM_SWAGGER_SPEC'] ||
                  "http://#{TM_HOSTNAME}:#{TM_PORT}/swagger/v1/swagger.json"

SCHEDULER.every '30s', first_in: 0 do |_|
  begin
    diff = Swagger::Diff::Diff.new(LOCAL_TM_SWAGGER_SPEC, TM_SWAGGER_SPEC)
    send_event('compare_swagger_files', value: diff.compatible?)
  rescue StandardError
    send_event('compare_swagger_files', value: false, fatal: true)
    raise
  end
end
