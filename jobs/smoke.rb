# frozen_string_literal: true

require 'open-uri'
require 'httparty'
require 'json'
require 'logger'

logger = Logger.new(STDOUT)
logger.level = Logger::WARN

RMA_HOSTNAME  = ENV['RM_ADAPTER_HOSTNAME']  || 'fwmtgatewayrmadapter'
RMA_PORT      = ENV['RM_ADAPTER_PORT']      || '80'
RMA_USERNAME  = ENV['RM_ADAPTER_USERNAME']  || ''
RMA_PASSWORD  = ENV['RM_ADAPTER_PASSWORD']  || ''

RMA_HEALTH_URL = "http://#{RMA_HOSTNAME}:#{RMA_PORT}/health"
RMA_INFO_URL = "http://#{RMA_HOSTNAME}:#{RMA_PORT}/info"
RMA_AUTH = { username: RMA_USERNAME, password: RMA_PASSWORD }.freeze

JOBSVC_HOSTNAME = ENV['JOB_SERVICE_HOSTNAME'] || 'fwmtgatewayjobsvc'
JOBSVC_PORT     = ENV['JOB_SERVICE_PORT']     || '80'
JOBSVC_USERNAME = ENV['JOB_SERVICE_USERNAME'] || ''
JOBSVC_PASSWORD = ENV['JOB_SERVICE_PASSWORD'] || ''

JOBSVC_HEALTH_URL = "http://#{JOBSVC_HOSTNAME}:#{JOBSVC_PORT}/health"
JOBSVC_INFO_URL = "http://#{JOBSVC_HOSTNAME}:#{JOBSVC_PORT}/info"
JOBSVC_AUTH = { username: JOBSVC_USERNAME, password: JOBSVC_PASSWORD }.freeze

TIMEOUT = 3

def send_aliveness_status(alive, id, name, fatal: false)
  p id
  send_event(id,
             alive: alive,
             fatal: fatal)
end

# check if the service is up via the info url, return whether it is up
def do_alive_check(partial_id, name, auth, info_url)
  HTTParty.get(info_url, timeout: TIMEOUT, basic_auth: auth)
  send_aliveness_status(true, "#{partial_id}_alive", name)
  [true, nil]
rescue HTTParty::ResponseError, Errno::ECONNREFUSED => e
  send_aliveness_status(false, "#{partial_id}_alive", name)
  [false, e]
rescue StandardError => e
  send_aliveness_status(false, "#{partial_id}_alive", name, fatal: true)
  [false, e]
end

def send_queues_accessible(id, name)
  send_event(id,
             title: "#{name} Queues Accessible",
             error: false,
             missingText: '')
end

def send_queues_inaccessible(id, name, text)
  send_event(id,
             title: "#{name} Queues Inaccessible",
             error: true,
             missingText: text)
end

def send_queues_alive(id, name, missing)
  if missing.empty?
    send_queues_accessible(id, name, **keywords)
  else
    text = 'Missing: ' + missing.join(', ')
    send_queues_inaccessible(id, name, text)
  end
end

def send_queues_dead(id, name)
  send_event(id,
             title: "#{name} Queues Inaccessible",
             dead: true,
             missingText: "#{name} Dead")
end

def send_queues_status(alive, missing, id, name, **keywords)
  if alive
    if missing.empty?
      send_queues_accessible(id, name, **keywords)
    else
      text = 'Missing: ' + missing.join(', ')
      send_queues_inaccessible(id, name, text)
    end
  else
    send_queues_dead(id, name)
  end
end

def get_health(health_url, auth)
  JSON.parse(
    HTTParty.get(health_url, timeout: TIMEOUT, basic_auth: auth).body
  )
end

def do_queue_check(is_alive, partial_id, name, auth, health_url)
  if is_alive
    health = get_health(health_url, auth)
    queues = health['details']['rabbitQueues']['details']['accessible-queues']
    queues_missing = queues.reject { |_, value| value }.map { |key, _| key }
    send_queues_status(true, queues_missing, "#{partial_id}_queues", name)
  else
    send_queues_status(false, [], "#{partial_id}_queues", name)
  end
rescue StandardError => e
  e
end

def do_service_check(partial_id:, name:, auth:, info_url:, health_url:)
  is_alive, error = do_alive_check(partial_id, name, auth, info_url)
  do_queue_check(is_alive, partial_id, name, auth, health_url)
  raise error unless is_alive
end

SCHEDULER.every '30s', first_in: 0 do |_|
  do_service_check(partial_id: 'rmadapter',
                   name: 'RM Adapter',
                   auth: RMA_AUTH,
                   info_url: RMA_INFO_URL,
                   health_url: RMA_HEALTH_URL)
end

SCHEDULER.every '30s', first_in: 0 do |_|
  do_service_check(partial_id: 'jobsvc',
                   name: 'Job Service',
                   auth: JOBSVC_AUTH,
                   info_url: JOBSVC_INFO_URL,
                   health_url: JOBSVC_HEALTH_URL)
end
