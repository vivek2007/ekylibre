module ActionCaller
  # Response object that includes the DSL methods.
  class Response
    attr_reader :code, :headers, :body
    attr_reader :state

    def initialize(params)
      @code = params[:code]
      @headers = params[:headers]
      @body = params[:body]
    end

    def self.new_from_net(net_response)
      new(
        code: net_response.code,
        headers: net_response.to_hash,
        body: net_response.body
      )
    end

    def self.new_from_httpi(httpi_response)
      new(
        code: httpi_response.code,
        headers: httpi.headers,
        body: httpi.raw_body
      )
    end

    def success(success_code = nil, &block)
      state_handling(:success, '2', success_code, &block)
    end

    def redirect(redirect_code = nil, &block)
      state_handling(:redirect, '3', redirect_code, &block)
    end

    def error(error_code = nil, &block)
      state_handling(:error, %w(4 5), error_code, &block)
    end

    def client_error(error_code = nil, &block)
      state_handling(:error, '4', error_code, &block)
    end

    def server_error(error_code = nil, &block)
      state_handling(:error, '5', error_code, &block)
    end

    def state=(signal)
      @state = @state_code || signal
    end

    private

    def state_handling(signal, http_codes, code = nil)
      return unless code_match?(@code, http_codes)
      if block_given?
        yield
      else
        @state_code = [signal, code].compact.join('_').to_sym
      end
      self.state = signal.to_sym
    end

    def code_match?(code, http_codes)
      return http_codes.include?(code.first.to_s) if http_codes.is_a? Array
      http_codes.to_s == code.first.to_s
    end
  end
end
