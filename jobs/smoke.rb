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

RM_ADAPTER_INFO_URL = "http://#{RM_ADAPTER_HOSTNAME}:#{RM_ADAPTER_PORT}/info"
JOB_SERVICE_INFO_URL = "http://#{JOB_SERVICE_HOSTNAME}:#{JOB_SERVICE_PORT}/info"

RM_ADAPTER_QUEUES_URL = "http://#{RM_ADAPTER_HOSTNAME}:#{RM_ADAPTER_PORT}/rabbitHealth"
JOB_SERVICE_QUEUES_URL = "http://#{JOB_SERVICE_HOSTNAME}:#{JOB_SERVICE_PORT}/rabbitHealth"

RM_ADAPTER_AUTH = {:username => RM_ADAPTER_USERNAME, :password => RM_ADAPTER_PASSWORD}
JOB_SERVICE_AUTH = {:username => JOB_SERVICE_USERNAME, :password => JOB_SERVICE_PASSWORD}

TIMEOUT = 3

def send_rmadapter_status(alive = true)
  send_event('rmadapter_alive', {
               title: alive ? "RM Adapter Alive" : "RM Adapter Dead",
               isDead: !alive,
             })
end

def send_jobsvc_status(alive = true)
  send_event('jobsvc_alive', {
               title: alive ? "Job Service Alive" : "Job Service Dead",
               isDead: !alive,
             })
end

def queue_missing_message(missing = [])
  missing.empty? ? "" : "Missing: " + missing.join(", ")
end

def send_rmadapter_queue_status(alive = true, missing = [])
  send_event('rmadapter_queues', {
               title: (alive && missing.empty?) ? "RM Adapter Queues Accessible" : "RM Adapter Queues Inaccessible",
               isDead: !alive || !missing.empty?,
               missingText: alive ? queue_missing_message(missing) : "RM Adapter Dead",
             })
end

def send_jobsvc_queue_status(alive = true, missing = [])
  send_event('jobsvc_queues', {
               title: (alive && missing.empty?) ? "Job Service Queues Accessible" : "Job Service Queues Inaccessible",
               isDead: !alive || !missing.empty?,
               missingText: alive ? queue_missing_message(missing) : "Job Service Dead",
             })
end

SCHEDULER.every '30s', :first_in => 0 do |job|
  rmadapter_alive = HTTParty.get(RM_ADAPTER_INFO_URL, {timeout: TIMEOUT, basic_auth: RM_ADAPTER_AUTH}) && true rescue false
  send_rmadapter_status(rmadapter_alive)
  if rmadapter_alive
    rmadapter_health = JSON.parse(HTTParty.get(RM_ADAPTER_HEALTH_URL, {timeout: TIMEOUT, basic_auth: RM_ADAPTER_AUTH}).body)
    rmadapter_queues = rmadapter_health["details"]["rabbitQueues"]["details"]["accessible-queues"]
    rmadapter_queues_missing = rmadapter_queues.select { |key, value| !value }.map { |key, value| key }
    send_rmadapter_queue_status(alive=true, missing=rmadapter_queues_missing)
  else
    send_rmadapter_queue_status(alive=false)
  end

  jobsvc_alive = HTTParty.get(JOB_SERVICE_INFO_URL, {timeout: TIMEOUT, basic_auth: JOB_SERVICE_AUTH}) && true rescue false
  send_jobsvc_status(jobsvc_alive)
  if jobsvc_alive
    jobsvc_health = JSON.parse(HTTParty.get(JOB_SERVICE_HEALTH_URL, {timeout: TIMEOUT, basic_auth: JOB_SERVICE_AUTH}).body)
    jobsvc_queues = jobsvc_health["details"]["rabbitQueues"]["details"]["accessible-queues"]
    jobsvc_queues_missing = jobsvc_queues.select { |key, value| !value }.map { |key, value| key }
    send_jobsvc_queue_status(alive=true, missing=jobsvc_queues_missing)
  else
    send_jobsvc_queue_status(alive=false)
  end
end
