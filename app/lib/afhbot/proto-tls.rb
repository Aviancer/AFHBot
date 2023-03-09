require 'openssl'
require 'socket'

module AFHBot

  class TLSSocket
  
    attr_accessor :tls_socket

    def initialize(log, host, port)
      @log = log
      @host = host
      @port = port

      # Load system CA certificates
      @cert_store = OpenSSL::X509::Store.new
      @cert_store.set_default_paths
      
      @tls_context = OpenSSL::SSL::SSLContext.new()
      @tls_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
      @tls_context.cert_store = @cert_store
      # https://www.tenable.com/plugins/nessus/156899 (2023.03.09)
      @tls_context.ssl_version = :TLSv1_2
      @tls_context.ciphers = [
        "ECDHE-ECDSA-AES256-GCM-SHA384",
        "ECDHE-RSA-AES256-GCM-SHA384",
        "ECDHE-ECDSA-AES128-GCM-SHA256",
        "ECDHE-RSA-AES128-GCM-SHA256",
        "ECDHE-ECDSA-CHACHA20-POLY1305",
        "ECDHE-RSA-CHACHA20-POLY1305",
        "DHE-RSA-AES128-GCM-SHA256",
        "DHE-RSA-AES256-GCM-SHA384"
      ]
      @tls_context.options |= OpenSSL::SSL::OP_NO_COMPRESSION
    end

    def connect
      begin
        @tcp_socket = TCPSocket.new(@host, @port)
        @tls_socket = OpenSSL::SSL::SSLSocket.new(@tcp_socket, @tls_context)
        @tls_socket.connect
        @tls_socket.sync_close = true
      rescue Errno::ERRCONNREFUSED, Errno::ETIMEDOUT => e
        return e
      end

      # 0=OK, otherwise errors
      verify_result = @tls_socket.verify_result
      if verify_result != 0
        @errors = Hash.new
        OpenSSL::X509.constants.grep(/^V_(ERR_|OK)/).each do |name|
            @errors[OpenSSL::X509.const_get(name)] = name
        end
        @status = @errors[@tls_socket.verify_result] # Status string
      else
        verify_result = true
      end
      verify_result
    end
    
    def write(message)
      @tls_socket.write message
    end

    def read(length)
      @tls_socket.read length
    end

    def puts(message)
      @tls_socket.puts message
    end
  
    def gets(length=$/)
      @tls_socket.gets(length)
    end

    def close
      @tls_socket.close
    end

    def alive?
      ! @tcp_socket.closed?
    end

    def readable?
      IO.select([@tcp_socket], [], [], 0) != nil
    end

    def writable?
      IO.select([], [@tcp_socket], [], 0) != nil
    end

  end

end
