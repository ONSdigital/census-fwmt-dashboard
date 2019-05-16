# frozen_string_literal: true

require 'bunny'

RABBITMQ_HOSTNAME = ENV['RABBITMQ_HOSTNAME'] || 'rabbitmq'

SCHEDULER.every '30s', first_in: 0 do |_|
  conn = Bunny.new(host: RABBITMQ_HOSTNAME,
                   port: '5672',
                   vhost: '/',
                   user: 'guest',
                   password: 'guest')
  conn.start
  ch = conn.create_channel

  dlq1 = ch.queue('Gateway.ActionsDLQ', durable: true)
  send_event('rabbitmq_queues_actionDLQ', count: dlq1.message_count.to_i)

  dlq2 = ch.queue('Action.FieldDLQ', durable: true)
  send_event('rabbitmq_queues_fieldDLQ', count: dlq2.message_count.to_i)

  dlq3 = ch.queue('Gateway.OutcomeDLQ', durable: true)
  send_event('rabbitmq_queues_outcomeDLQ', count: dlq3.message_count.to_i)

  conn.close
end
