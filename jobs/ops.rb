require 'bunny'
require 'digest'
require 'open-uri'
require 'net/http'
require 'httparty'
require 'swagger/diff'

ACTION_SERVICE_XSD_URL = ENV['ACTION_SERVICE_XSD_URL'] || 'https://raw.githubusercontent.com/ONSdigital/rm-actionsvc-api/master/src/main/resources/actionsvc/xsd/actionInstruction.xsd'
RM_ADAPTER_XSD_URL = ENV['RM_ADAPTER_XSD_URL'] || 'https://raw.githubusercontent.com/ONSdigital/census-fwmt-rm-adapter/master/src/main/resources/xsd/actionInstruction.xsd'
LOCAL_TM_SWAGGER_SPEC = ENV['LOCAL_TM_SWAGGER_SPEC'] || 'https://raw.githubusercontent.com/ONSdigital/census-fwmt-job-service/master/src/main/resources/tm-swagger.json'

RABBITMQ_HOSTNAME = ENV['RABBITMQ_HOSTNAME'] || 'rabbitmq'
TM_HOSTNAME = ENV['TM_HOSTNAME'] || 'tm'
TM_PORT = ENV['TM_PORT'] || '80'

TM_SWAGGER_SPEC = "https://#{TM_HOSTNAME}:#{TM_PORT}/swagger/v1/swagger.json"

ACTION_SERVICE_XSD = '/tmp/actionServiceXSD.xsd'
RM_ADAPTER_XSD = '/tmp/rmAdapterXSD.xsd'

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
SCHEDULER.every '30s', :first_in => 0 do |job|

  #check size of DLQs
  conn = Bunny.new(host: RABBITMQ_HOSTNAME, port: '5672', vhost: '/', user: 'guest', password: 'guest')
  conn.start
  ch = conn.create_channel
  dlq1 = ch.queue("Gateway.ActionsDLQ", durable: true)
  send_event('rabbitmq_queues_1', { name: "Gateway.ActionsDLQ", count: dlq1.message_count })
  dlq2 = ch.queue("Action.FieldDLQ", durable: true)
  send_event('rabbitmq_queues_2', { name: "Action.FieldDLQ", count: dlq2.message_count })
  dlq2 = ch.queue("Gateway.OutcomeDLQ", durable: true)
  send_event('rabbitmq_queues_3', { name: "Gateway.OutcomeDLQ", count: dlq2.message_count })

  #check MD5 for XSD files
  File.open(ACTION_SERVICE_XSD, "w+") { |f| f.write HTTParty.get(ACTION_SERVICE_XSD_URL).body }
  File.open(RM_ADAPTER_XSD, "w+") { |f| f.write HTTParty.get(RM_ADAPTER_XSD_URL).body }
  send_event('compare_xsd_files', { value: Digest::MD5.file(ACTION_SERVICE_XSD) == Digest::MD5.file(RM_ADAPTER_XSD) })

  # Check Swagger specs
  diff = Swagger::Diff::Diff.new(LOCAL_TM_SWAGGER_SPEC, TM_SWAGGER_SPEC)
  send_event('compare_swagger_files', { value: diff.compatible? })

end
