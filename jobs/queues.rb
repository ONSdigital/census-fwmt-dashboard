# frozen_string_literal: true

require 'bunny'

# automatically populated
RABBITMQ_HOSTNAME = ENV['RABBITMQ_SERVICE_HOST'] || 'rabbitmq'
RABBITMQ_PORT = ENV['RABBITMQ_SERVICE_PORT'] || '5672'

RABBITMQ_VHOST = ENV['RABBITMQ_VHOST'] || '/'
RABBITMQ_USERNAME = ENV['RABBITMQ_USERNAME'] || 'guest'
RABBITMQ_PASSWORD = ENV['RABBITMQ_PASSWORD'] || 'guest'

SCHEDULER.every '30s', first_in: 0 do |_|
  conn = Bunny.new(host: RABBITMQ_HOSTNAME,
                   port: RABBITMQ_PORT,
                   vhost: RABBITMQ_VHOST,
                   user: RABBITMQ_USERNAME,
                   password: RABBITMQ_PASSWORD)
  conn.start
  ch = conn.create_channel

  dlq1 = ch.queue('Gateway.ActionsDLQ', durable: true)
  send_event('rabbitmq_queue_actionDLQ', count: dlq1.message_count.to_i)

  dlq2 = ch.queue('Action.FieldDLQ', durable: true)
  send_event('rabbitmq_queue_fieldDLQ', count: dlq2.message_count.to_i)

  dlq3 = ch.queue('Gateway.OutcomeDLQ', durable: true)
  send_event('rabbitmq_queue_outcomeDLQ', count: dlq3.message_count.to_i)

  conn.close
end
