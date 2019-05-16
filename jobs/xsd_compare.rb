# frozen_string_literal: true

require 'digest'
require 'httparty'

# remote file locations
ACTIONSVC_XSD_URL = ENV['ACTION_SERVICE_XSD_URL'] || 'https://raw.githubusercontent.com/ONSdigital/rm-actionsvc-api/master/src/main/resources/actionsvc/xsd/actionInstruction.xsd'
RMA_XSD_URL = ENV['RM_ADAPTER_XSD_URL'] || 'https://raw.githubusercontent.com/ONSdigital/census-fwmt-rm-adapter/master/src/main/resources/xsd/actionInstruction.xsd'

SCHEDULER.every '30s', first_in: 0 do |_|
  begin
    actsvc_xsd_hash = Digest::MD5.digest(HTTParty.get(ACTIONSVC_XSD_URL).body)
    rma_xsd_hash = Digest::MD5.digest(HTTParty.get(RMA_XSD_URL).body)
    is_compatible = actsvc_xsd_hash == rma_xsd_hash
    send_event('compare_xsd_files', value: is_compatible, fatal: false)
  rescue StandardError
    send_event('compare_xsd_files', value: false, fatal: true)
    raise
  end
end
