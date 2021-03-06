require 'goliath/rack/validation_error'

module Goliath
  module Rack
    module Validation
      # A middleware to validate that a given parameter is provided.
      #
      # @example
      #  use Goliath::Rack::Validation::RequiredParam, {:key => 'mode', :type => 'Mode'}
      #
      class RequiredParam
        attr_reader :type, :key

        # Creates the Goliath::Rack::Validation::RequiredParam validator
        #
        # @param app The app object
        # @param opts [Hash] The validator options
        # @option opts [String] :key The key to look for in params (default: id)
        # @option opts [String] :type The type string to put in the error message. (default: :key)
        # @return [Goliath::Rack::Validation::RequiredParam] The validator
        def initialize(app, opts = {})
          @app = app
          @key = opts[:key] || 'id'
          @type = opts[:type] || @key.capitalize
        end

        def call(env)
          key_valid!(env['params'])
          @app.call(env)
        end

        def key_valid!(params)
          error = false
          if !params.has_key?(key) || params[key].nil? ||
              (params[key].is_a?(String) && params[key] =~ /^\s*$/)
            error = true
          end

          if params[key].is_a?(Array)
            unless params[key].compact.empty?
              params[key].each do |k|
                return unless k.is_a?(String)
                return unless k =~ /^\s*$/
              end
            end
            error = true
          end

          raise Goliath::Validation::Error.new(400, "#{@type} identifier missing") if error
        end
      end
    end
  end
end