# frozen_string_literal: true

require 'open-uri'
require 'httparty'
require 'json'
require 'logger'

logger = Logger.new(STDOUT)
logger.level = Logger::WARN

RMA_HOSTNAME  = ENV['RM_ADAPTER_HOSTNAME']  || 'fwmtgatewayrmadapter'
RMA_PORT      = ENV['RM_ADAPTER_PORT']      || '80'
RMA_USERNAME  = ENV['RM_ADAPTER_USERNAME']  || nil
RMA_PASSWORD  = ENV['RM_ADAPTER_PASSWORD']  || nil

RMA_HEALTH_URL = "http://#{RMA_HOSTNAME}:#{RMA_PORT}/health"
RMA_INFO_URL = "http://#{RMA_HOSTNAME}:#{RMA_PORT}/info"
RMA_AUTH = if RMA_USERNAME || RMA_PASSWORD
             { username: RMA_USERNAME, password: RMA_PASSWORD }.freeze
           end

JOBSVC_HOSTNAME = ENV['JOB_SERVICE_HOSTNAME'] || 'fwmtgatewayjobsvc'
JOBSVC_PORT     = ENV['JOB_SERVICE_PORT']     || '80'
JOBSVC_USERNAME = ENV['JOB_SERVICE_USERNAME'] || nil
JOBSVC_PASSWORD = ENV['JOB_SERVICE_PASSWORD'] || nil

JOBSVC_HEALTH_URL = "http://#{JOBSVC_HOSTNAME}:#{JOBSVC_PORT}/health"
JOBSVC_INFO_URL = "http://#{JOBSVC_HOSTNAME}:#{JOBSVC_PORT}/info"
JOBSVC_AUTH = if JOBSVC_USERNAME || JOBSVC_PASSWORD
                { username: JOBSVC_USERNAME, password: JOBSVC_PASSWORD }.freeze
              end

TIMEOUT = 3

# Utility

def send_text_status(id, text, more_info: '', danger: false, fatal: false)
  send_event(id, text: text, more_info: more_info, danger: danger, fatal: fatal)
end

# Service aliveness

def send_service_response(id, response)
  ok = response.code == 200
  if ok
    send_text_status(id, 'Alive')
    [true, nil]
  else
    msg = "Response code: #{response.code}"
    send_text_status(id, 'Faulty', more_info: msg, danger: true)
    [false, nil]
  end
end

# check if the service is up via the info url, return whether it is up
def do_alive_check(id, auth, info_url)
  response = HTTParty.get(info_url, timeout: TIMEOUT, basic_auth: auth)
  send_service_response(id, response)
rescue HTTParty::ResponseError, Errno::ECONNREFUSED => e
  send_text_status(id, 'Dead', more_info: e.message, danger: true)
  [false, exception]
rescue StandardError => e
  send_text_status(id, 'Indeterminate', more_info: e.message, fatal: true)
  [false, exception]
end

# Queue access

def get_accessible_queues(health_url, auth)
  body = HTTParty.get(health_url, timeout: TIMEOUT, basic_auth: auth).body
  health = JSON.parse(body)
  health['details']['rabbitQueues']['details']['accessible-queues']
end

# half-gutted
def send_queues_status(id, name, missing: [])
  send_queues_status_fatal(id, name) if fatal
  accessible = missing.empty? && alive
  title = "#{name} Queues #{accessible ? 'Accessible' : 'Inaccessible'}"
  text = if !alive then 'Service Dead'
         elsif missing.empty? then ''
         else 'Missing: ' + missing.join(', ')
         end
  send_event(id, title: title, text: text, error: !alive, fatal: fatal)
end

# half-gutted
def do_queues_check(id, name, auth, health_url)
  queues = get_accessible_queues(health_url, auth)
  queues_missing = queues.reject { |_, value| value }.map { |key, _| key }
  send_queues_status(id, name, missing: queues_missing)
  send_text_status(id, name, more_info: e.message, fatal: true)
  [true, nil]
rescue StandardError => e
  send_text_status(id, name, more_info: e.message, fatal: true)
  [false, e]
end

# Combined checks

def do_smoke_check(partial_id:, name:, auth:, info_url:, health_url:)
  a_id = "#{partial_id}_alive"
  q_id = "#{partial_id}_queues"
  is_alive, a_error = do_alive_check(a_id, auth, info_url)
  if is_alive
    _, q_error = do_queue_check(q_id, name, auth, health_url)
  else
    send_text_status(q_id, 'Indeterminate', danger: true)
  end
  raise a_error if a_error
  raise q_error if q_error
end

SCHEDULER.every '30s', first_in: 0 do |_|
  do_smoke_check(partial_id: 'rmadapter',
                 name: 'RM Adapter',
                 auth: RMA_AUTH,
                 info_url: RMA_INFO_URL,
                 health_url: RMA_HEALTH_URL)
end

SCHEDULER.every '30s', first_in: 0 do |_|
  do_smoke_check(partial_id: 'jobsvc',
                 name: 'Job Service',
                 auth: JOBSVC_AUTH,
                 info_url: JOBSVC_INFO_URL,
                 health_url: JOBSVC_HEALTH_URL)
end

# ---

def send_aliveness_status(alive, id, fatal: false)
  send_event(id, alive: alive, fatal: fatal)
end

# check if the service is up via the info url, return whether it is up
def do_alive_check(partial_id, auth, info_url)
  HTTParty.get(info_url, timeout: TIMEOUT, basic_auth: auth)
  send_aliveness_status(true, "#{partial_id}_alive")
  [true, nil]
rescue HTTParty::ResponseError, Errno::ECONNREFUSED => e
  send_aliveness_status(false, "#{partial_id}_alive")
  [false, e]
rescue StandardError => e
  send_aliveness_status(false, "#{partial_id}_alive", fatal: true)
  [false, e]
end

def send_queues_status_fatal(id, name)
  title = "#{name} Queues Uncheckable"
  text = 'Fatal Error'
  send_event(id, title: title, text: text, error: false, fatal: true)
end

def send_queues_status(id, name, alive: true, missing: [], fatal: false)
  send_queues_status_fatal(id, name) if fatal
  accessible = missing.empty? && alive
  title = "#{name} Queues #{accessible ? 'Accessible' : 'Inaccessible'}"
  text = if !alive then 'Service Dead'
         elsif missing.empty? then ''
         else 'Missing: ' + missing.join(', ')
         end
  send_event(id, title: title, text: text, error: !alive, fatal: fatal)
end

def get_health(health_url, auth)
  JSON.parse(HTTParty.get(health_url, timeout: TIMEOUT, basic_auth: auth).body)
end

def do_queue_skip(partial_id, name)
  send_queues_status("#{partial_id}_queues", name, alive: false)
end

def do_queue_check(partial_id, name, auth, health_url)
  health = get_health(health_url, auth)
  queues = health['details']['rabbitQueues']['details']['accessible-queues']
  queues_missing = queues.reject { |_, value| value }.map { |key, _| key }
  send_queues_status("#{partial_id}_queues", name, missing: queues_missing)
  nil
rescue StandardError => e
  send_queues_status("#{partial_id}_queues", name, fatal: true)
  e
end

def do_service_check(partial_id:, name:, auth:, info_url:, health_url:)
  is_alive, aliveness_error = do_alive_check(partial_id, auth, info_url)
  if is_alive
    queues_error = do_queue_check(partial_id, name, auth, health_url)
  else
    do_queue_skip(partial_id, name)
  end
  raise aliveness_error if aliveness_error
  raise queues_error if queues_error
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
