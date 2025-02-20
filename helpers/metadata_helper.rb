require 'sinatra/base'
require 'date'

module Sinatra
  module Helpers
    module MetadataHelper

      def klass_metadata(klass, type)
        all_attr = []
        klass.attributes(:all).each do |attr|

          id_url_prefix = if LinkedData.settings.id_url_prefix.nil? || LinkedData.settings.id_url_prefix.empty?
                            'http://data.bioontology.org/'
                          else
                            LinkedData.settings.id_url_prefix
                          end

          attr_settings = {}
          attr_settings[:@id] = "#{id_url_prefix}#{type}/#{attr.to_s}"
          attr_settings[:@type] = "#{id_url_prefix}metadata/#{type.camelize}"
          attr_settings[:attribute] = attr.to_s

          # Get metadata namespace
          attr_settings[:namespace] = if klass.attribute_settings(attr)[:namespace].nil?
                                        nil
                                      else
                                        klass.attribute_settings(attr)[:namespace].to_s
                                      end

          # Get metadata label if one
          attr_settings[:label] = if klass.attribute_settings(attr)[:label].nil?
                                    nil
                                  else
                                    klass.attribute_settings(attr)[:label]
                                  end

          # Get if it is an extracted metadata
          attr_settings[:extracted] = klass.attribute_settings(attr)[:extractedMetadata].eql?('true') ? 'true' : 'false'

          # Get mappings of the metadata
          attr_settings[:metadataMappings] = if klass.attribute_settings(attr)[:metadataMappings].nil?
                                               nil
                                             else
                                               klass.attribute_settings(attr)[:metadataMappings]
                                             end

          # Get enforced from the metadata
          attr_settings[:enforce] = []
          klass.attribute_settings(attr)[:enforce]&.each do |enforced|
              next if enforced.is_a?(Proc)
              
              attr_settings[:enforce] << enforced.to_s
          end

          # Get enforcedValues from the metadata
          attr_settings[:enforcedValues] = klass.attribute_settings(attr)[:enforcedValues]

          # Get display from the metadata
          attr_settings[:category] = if klass.attribute_settings(attr)[:display].nil?
                                       'no'
                                     else
                                       klass.attribute_settings(attr)[:display]
                                     end

          unless klass.attribute_settings(attr)[:helpText].nil?
            attr_settings[:helpText] = klass.attribute_settings(attr)[:helpText]
          end

          unless klass.attribute_settings(attr)[:description].nil?
            attr_settings[:description] = klass.attribute_settings(attr)[:description]
          end

          unless klass.attribute_settings(attr)[:example].nil?
            attr_settings[:example] = klass.attribute_settings(attr)[:example]
          end

          attr_settings[:@context] = {
            '@vocab' => "#{id_url_prefix}metadata/"
          }

          all_attr << attr_settings
        end
        all_attr
      end
    end
  end
end

helpers Sinatra::Helpers::MetadataHelper
