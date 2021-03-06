# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class DynamoDBSpy
      def self.without_net_http
        return yield unless defined?(NetHTTPSpy)

        ElasticAPM::Spies::NetHTTPSpy.disable_in do
          yield
        end
      end

      def install
        ::Aws::DynamoDB::Client.class_eval do
          # Alias all available operations
          api.operation_names.each do |operation_name|
            alias :"#{operation_name}_without_apm" :"#{operation_name}"

            define_method(operation_name) do |params = {}, options = {}|
              ElasticAPM.with_span(operation_name, 'db', subtype: 'dynamodb', action: operation_name) do
                ElasticAPM::Spies::DynamoDBSpy.without_net_http do
                  original_method = method("#{operation_name}_without_apm")
                  original_method.call(params, options)
                end
              end
            end
          end
        end
      end
    end

    register(
      'Aws::DynamoDB::Client',
      'aws-sdk-dynamodb',
      DynamoDBSpy.new
    )
  end
end
