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

def send_text_status(id, text, **options)
  defaults = { moreinfo: '', warning: false, danger: false, fatal: false }
  send_event(id, text: text, **defaults.merge(options))
end

# Service aliveness

def send_service_response(id, response)
  ok = response.code == 200
  if ok
    send_text_status(id, 'Alive')
    [true, nil]
  else
    msg = "Response code: #{response.code}"
    send_text_status(id, 'Faulty', moreinfo: msg, danger: true)
    [false, nil]
  end
end

# check if the service is up via the info url, return whether it is up
def do_alive_check(id, auth, info_url)
  response = HTTParty.get(info_url, timeout: TIMEOUT, basic_auth: auth)
  send_service_response(id, response)
rescue HTTParty::ResponseError, Errno::ECONNREFUSED => e
  send_text_status(id, 'Dead', moreinfo: e.message, danger: true)
  [false, e]
rescue StandardError => e
  send_text_status(id, 'Indeterminate', moreinfo: e.message, fatal: true)
  [false, e]
end

# Queue access

def get_missing_queues(health_url, auth)
  body = HTTParty.get(health_url, timeout: TIMEOUT, basic_auth: auth).body
  health = JSON.parse(body)
  accessible = health['details']['rabbitQueues']['details']['accessible-queues']
  accessible.reject { |_, value| value }.map { |key, _| key }
end

def send_queues_status(id, missing)
  text = missing.empty? ? 'Accessible' : 'Inaccessible'
  info = missing.empty? ? '' : 'Missing: ' + missing.join(', ')
  send_text_status(id, text, moreinfo: info, danger: !missing.empty?)
end

def send_queues_unchecked(id)
  send_text_status(id,
                   'Indeterminate',
                   moreinfo: 'Service Dead',
                   warning: true)
end

def do_queues_check(id, auth, health_url)
  queues_missing = get_missing_queues(health_url, auth)
  send_queues_status(id, queues_missing)
  [true, nil]
rescue StandardError => e
  send_text_status(id, 'Uncheckable', moreinfo: e.message, fatal: true)
  [false, e]
end

# Combined checks

def do_smoke_check(partial_id:, auth:, info_url:, health_url:)
  a_id = "#{partial_id}_alive"
  q_id = "#{partial_id}_queues"
  is_alive, a_error = do_alive_check(a_id, auth, info_url)
  if is_alive
    _, q_error = do_queues_check(q_id, auth, health_url)
  else
    send_queues_unchecked(q_id)
  end
  raise a_error if a_error
  raise q_error if q_error
end

SCHEDULER.every '30s', first_in: 0 do |_|
  do_smoke_check(partial_id: 'rmadapter',
                 auth: RMA_AUTH,
                 info_url: RMA_INFO_URL,
                 health_url: RMA_HEALTH_URL)
end

SCHEDULER.every '30s', first_in: 0 do |_|
  do_smoke_check(partial_id: 'jobsvc',
                 auth: JOBSVC_AUTH,
                 info_url: JOBSVC_INFO_URL,
                 health_url: JOBSVC_HEALTH_URL)
end

