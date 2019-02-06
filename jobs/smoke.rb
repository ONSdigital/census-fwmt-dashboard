require 'open-uri'
require 'net/http'
require 'httparty'
require 'json'

RM_ADAPTER_HOSTNAME  = ENV['RM_ADAPTER_HOSTNAME']  || 'fwmtgatewayrmadapter'
RM_ADAPTER_PORT      = ENV['RM_ADAPTER_PORT']      || '80'
RM_ADAPTER_USERNAME  = ENV['RM_ADAPTER_USERNAME']  || ''
RM_ADAPTER_PASSWORD  = ENV['RM_ADAPTER_PASSWORD']  || ''
JOB_SERVICE_HOSTNAME = ENV['JOB_SERVICE_HOSTNAME'] || 'fwmtgatewayjobsvc'
JOB_SERVICE_PORT     = ENV['JOB_SERVICE_PORT']     || '80'
JOB_SERVICE_USERNAME = ENV['JOB_SERVICE_USERNAME'] || ''
JOB_SERVICE_PASSWORD = ENV['JOB_SERVICE_PASSWORD'] || ''

RM_ADAPTER_INFO_URL = 'http://' + RM_ADAPTER_HOSTNAME + ':' + RM_ADAPTER_PORT + '/info'
JOB_SERVICE_INFO_URL = 'http://' + JOB_SERVICE_HOSTNAME + ':' + JOB_SERVICE_PORT + '/info'

RM_ADAPTER_QUEUES_URL = 'http://' + RM_ADAPTER_HOSTNAME + ':' + RM_ADAPTER_PORT + '/rabbitHealth'
JOB_SERVICE_QUEUES_URL = 'http://' + JOB_SERVICE_HOSTNAME + ':' + JOB_SERVICE_PORT + '/rabbitHealth'

RM_ADAPTER_AUTH = {:username => RM_ADAPTER_USERNAME, :password => RM_ADAPTER_PASSWORD}
JOB_SERVICE_AUTH = {:username => JOB_SERVICE_USERNAME, :password => JOB_SERVICE_PASSWORD}

TIMEOUT = 3

JOB_SERVICE_QUEUES = [
  # 'gateway.feedback',
  # 'gateway.feedback.DLQ',
  # 'gateway.actions',
  # 'gateway.actions.DLQ',
  'Gateway.Feedback',
  'Gateway.Actions',
  'Gateway.ActionsDLQ',
]

RM_ADAPTER_QUEUES = [
  # 'gateway.feedback',
  # 'gateway.feedback.DLQ',
  # 'gateway.actions',
  # 'gateway.actions.DLQ',
  # 'rm.feedback',
  # 'rm.feedback.DLQ',
  'Action.Field',
  'Action.FieldDLQ',
  'Gateway.Actions',
]

SCHEDULER.every '30s', :first_in => 0 do |job|
  rmadapter_alive = HTTParty.get(RM_ADAPTER_INFO_URL, {timeout: TIMEOUT, basic_auth: RM_ADAPTER_AUTH}) && true rescue false
  jobsvc_alive = HTTParty.get(JOB_SERVICE_INFO_URL, {timeout: TIMEOUT, basic_auth: JOB_SERVICE_AUTH}) && true rescue false
  send_event('rmadapter_alive', {
               title: rmadapter_alive ? "RM Adapter Alive" : "RM Adapter Dead",
               aliveness: rmadapter_alive,
             })
  send_event('jobsvc_alive', {
               title: rmadapter_alive ? "Job Service Alive" : "Job Service Dead",
               aliveness: jobsvc_alive,
             })

  rmadapter_queues = JSON.parse(HTTParty.get(RM_ADAPTER_QUEUES_URL, {timeout: TIMEOUT, basic_auth: RM_ADAPTER_AUTH}).body)
  jobsvc_queues = JSON.parse(HTTParty.get(JOB_SERVICE_QUEUES_URL, {timeout: TIMEOUT, basic_auth: JOB_SERVICE_AUTH}).body)
  rmadapter_queues_missing = RM_ADAPTER_QUEUES - rmadapter_queues
  rmadapter_queues_ok = rmadapter_queues_missing.empty?
  jobsvc_queues_missing = JOB_SERVICE_QUEUES - jobsvc_queues
  jobsvc_queues_ok = rmadapter_queues_missing.empty?
  send_event('rmadapter_queues', {
               title: rmadapter_queues_ok ? "RM Adapter Queues Accessible" : "RM Adapter Queues Inaccessible",
               missing: !rmadapter_queues_ok,
               missingText: rmadapter_queues_missing.to_s,
             })
  send_event('jobsvc_queues', {
               title: jobsvc_queues_ok ? "Job Service Queues Accessible" : "Job Service Queues Inaccessible",
               missing: !jobsvc_queues_ok,
               missingText: jobsvc_queues_missing.to_s,
             })
end
