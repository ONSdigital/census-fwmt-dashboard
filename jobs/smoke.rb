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

RM_ADAPTER_HOSTNAME  = ENV['RM_ADAPTER_URL']  || 'fwmtgatewayrmadapter'
JOB_SERVICE_HOSTNAME = ENV['JOB_SERVICE_URL'] || 'fwmtgatewayjobsvc'

RM_ADAPTER_INFO_URL = "http://" + RM_ADAPTER_HOSTNAME + "/info"
JOB_SERVICE_INFO_URL = "http://" + JOB_SERVICE_HOSTNAME + "/info"

RM_ADAPTER_QUEUES_URL = "http://" + RM_ADAPTER_HOSTNAME + "/rabbitHealth"
JOB_SERVICE_QUEUES_URL = "http://" + JOB_SERVICE_HOSTNAME + "/rabbitHealth"

TIMEOUT = 3

JOB_SERVICE_QUEUES = [
  "gateway.feedback",
  "gateway.feedback.DLQ",
  "gateway.actions",
  "gateway.actions.DLQ"
]

RM_ADAPTER_QUEUES = [
  "gateway.feedback",
  "gateway.feedback.DLQ",
  "gateway.actions",
  "gateway.actions.DLQ",
  "Action.Field",
  "Action.FieldDLQ",
  "rm.feedback",
  "rm.feedback.DLQ"
]

SCHEDULER.every '30s', :first_in => 0 do |job|
  rmadapter_alive = HTTParty.get(RM_ADAPTER_INFO_URL, {timeout: TIMEOUT}) && true rescue false
  jobsvc_alive = HTTParty.get(JOB_SERVICE_INFO_URL, {timeout: TIMEOUT}) && true rescue false
  send_event('rmadapter_alive', { aliveness: rmadapter_alive })
  send_event('jobsvc_alive', { aliveness: jobsvc_alive })

  rmadapter_queues = HTTParty.get(RM_ADAPTER_QUEUES_URL, {timeout: TIMEOUT}).body
  jobsvc_queues = HTTParty.get(JOB_SERVICE_QUEUES_URL, {timeout: TIMEOUT}).body
  rmadapter_queues_ok = RM_ADAPTER_QUEUES.sort == rmadapter_queues.sort
  jobsvc_queues_ok = JOB_SERVICE_QUEUES.sort == jobsvc_queues.sort
  send_event('rmadapter_queues_ok', { queues_exist: rmadapter_queues_ok })
  send_event('jobsvc_queues_ok', { aliveness: jobsvc_queues_ok })
end
