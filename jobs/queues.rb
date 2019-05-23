# frozen_string_literal: true

require 'bunny'

# RABBITMQ_SERVICE_HOST and RABBITMQ_SERVICE_PORT are
#  automatically populated in Kubernetes
RABBITMQ_HOSTNAME = ENV['RABBITMQ_SERVICE_HOST'] ||
                    ENV['RABBITMQ_HOSTNAME'] ||
                    'rabbitmq'
RABBITMQ_PORT = ENV['RABBITMQ_SERVICE_PORT'] ||
                ENV['RABBITMQ_PORT'] ||
                '5672'

RABBITMQ_VHOST = ENV['RABBITMQ_VHOST'] || '/'
RABBITMQ_USERNAME = ENV['RABBITMQ_USERNAME'] || 'guest'
RABBITMQ_PASSWORD = ENV['RABBITMQ_PASSWORD'] || 'guest'

RABBITMQ_DETAILS = {
  host: RABBITMQ_HOSTNAME,
  port: RABBITMQ_PORT,
  vhost: RABBITMQ_VHOST,
  user: RABBITMQ_USERNAME,
  password: RABBITMQ_PASSWORD
}.freeze

WIDGET_IDS = { rabbitmq_queue_actionDLQ: 'Gateway.ActionsDLQ',
               rabbitmq_queue_fieldDLQ: 'Action.FieldDLQ',
               rabbitmq_queue_outcomeDLQ: 'Gateway.OutcomeDLQ' }.freeze

def send_queue_status(id, status, **options)
  defaults = { messageCount: nil, warning: false, danger: false, fatal: false }
  send_event(id, status: status, **defaults.merge(options))
end

def send_rabbit_stats(id, message_count)
  send_queue_status(id, 'Up', messageCount: message_count)
end

def send_rabbit_down(id)
  send_queue_status(id, 'Down', messageCount: 'Undefined', fatal: true)
end

def do_queue_stats_update(id, queue_name, channel)
  queue = channel.queue(queue_name, durable: true)
  send_rabbit_stats(id, queue.message_count)
end

SCHEDULER.every '30s', first_in: 0 do |_|
  conn = Bunny.new(**RABBITMQ_DETAILS)
  conn.start
  ch = conn.create_channel

  WIDGET_IDS.each { |id, name| do_queue_stats_update(id, name, ch) }

  conn.close
rescue Bunny::TCPConnectionFailedForAllHosts => e
  WIDGET_IDS.each_key { |id| send_rabbit_down(id) }
  raise e
ensure
  conn.close
end
