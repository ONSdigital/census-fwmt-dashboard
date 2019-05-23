# frozen_string_literal: true

require 'digest'
require 'httparty'

# remote file locations
ACTIONSVC_XSD_URL = ENV['ACTION_SERVICE_XSD_URL'] || 'https://raw.githubusercontent.com/ONSdigital/rm-actionsvc-api/master/src/main/resources/actionsvc/xsd/actionInstruction.xsd'
RMA_XSD_URL = ENV['RM_ADAPTER_XSD_URL'] || 'https://raw.githubusercontent.com/ONSdigital/census-fwmt-rm-adapter/master/src/main/resources/xsd/actionInstruction.xsd'

def send_xsd_status(id, text, **options)
  defaults = { moreinfo: '', warning: false, danger: false, fatal: false }
  send_event(id, text: text, **defaults.merge(options))
end

def send_xsd_fatal(id, exception)
  send_xsd_status(id, 'Fatal Error', moreinfo: exception.message, fatal: true)
end

def get_digest(url)
  Digest::MD5.digest(HTTParty.get(url).body)
end

SCHEDULER.every '30s', first_in: 0 do |_|
  actsvc_xsd_hash = get_digest(ACTIONSVC_XSD_URL)
  rma_xsd_hash = get_digest(RMA_XSD_URL)
  is_compatible = actsvc_xsd_hash == rma_xsd_hash
  msg = is_compatible ? 'Matching' : 'Deviating'
  send_xsd_status('compare_xsd_files', msg, danger: !is_compatible)
rescue StandardError => e
  send_xsd_fatal('compare_xsd_files', e)
  raise
end
