require 'bunny'
require 'digest'
require 'open-uri'
require 'net/http'
require 'httparty'
require 'swagger/diff'

ACTION_SERVICE_XSD_URL = ENV['ACTION_SERVICE_XSD_URL']
RM_ADAPTER_XSD_URL     = ENV['RM_ADAPTER_XSD_URL']
RABBIT_URL             = ENV['RABBIT_URL']
TM_SWAGGER_SPEC        = ENV['TM_SWAGGER_SPEC']
LOCAL_TM_SWAGGER_SPEC  = ENV['LOCAL_TM_SWAGGER_SPEC']
ACTION_SERVICE_XSD    = '/tmp/actionServiceXSD.xsd'
RM_ADAPTER_XSD         = '/tmp/rmAdapterXSD.xsd'

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
SCHEDULER.every '5s', :first_in => 0 do |job|

  #check size of DLQs
  conn = Bunny.new(host: RABBIT_URL, port: '5672', vhost: '/', user: 'guest', password: 'guest')
  conn.start
  ch = conn.create_channel
  dlq1  = ch.queue("gateway.actions.DLQ", durable: true)
  send_event('rabbitmq_queues_1', { name: "gateway.actions.DLQ", count: dlq1.message_count })
  dlq2  = ch.queue("Action.FieldDLQ", durable: true)
  send_event('rabbitmq_queues_2', { name: "Action.FieldDLQ", count: dlq2.message_count })
  dlq3  = ch.queue("gateway.feedback.DLQ", durable: true)
  send_event('rabbitmq_queues_3', { name: "gateway.feedback.DLQ", count: dlq3.message_count })
  dlq4  = ch.queue("rm.feedback.DLQ", durable: true)
  send_event('rabbitmq_queues_4', { name: "rm.feedback.DLQ", count: dlq4.message_count })


  #check MD5 for XSD files
  File.open(ACTION_SERVICE_XSD, "w+") { |f| f.write HTTParty.get(ACTION_SERVICE_XSD_URL).body }
  File.open(RM_ADAPTER_XSD, "w+") { |f| f.write HTTParty.get(RM_ADAPTER_XSD_URL).body }
  send_event('compare_xsd_files', { value: Digest::MD5.file(ACTION_SERVICE_XSD) == Digest::MD5.file(RM_ADAPTER_XSD) })

  # Check Swagger specs
  diff = Swagger::Diff::Diff.new(LOCAL_TM_SWAGGER_SPEC, TM_SWAGGER_SPEC)
  send_event('compare_swagger_files', { value: diff.compatible? })


end
