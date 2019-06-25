# frozen_string_literal: true

require 'net/http'
require 'openssl'

module BoltSpec
  module BoltServer
    def default_config
      spec_dir = File.join(__dir__, '..', '..')
      ssl_dir = File.join(spec_dir, 'fixtures', 'ssl')
      {
        'ssl-cert' => File.join(ssl_dir, "cert.pem"),
        'ssl-key' => File.join(ssl_dir, "key.pem"),
        'ssl-ca-cert' => File.join(ssl_dir, "ca.pem"),
        'cache-dir' => File.join(spec_dir, "tmp", "cache"),
        'file-server-uri' => 'https://localhost:8140'
      }
    end

    def config_data
      default_config
    end

    def target2request(target, _type = :ssh)
      req = {
        'hostname' => target.host,
        'user' => target.user
      }

      req['password'] = target.password if target.password
      req['port'] = target.port if target.port
      req['user'] = target.user if target.user

      case target.protocol
      when 'ssh'
        req['host-key-check'] = false
        if target.options['private-key-content']
          req['private-key-content'] = target.options['private-key-content']
        elsif target.options['private-key']
          req['private-key-content'] = File.read(target.options['private-key'])
        end
        req['port'] ||= 22
        req['user'] ||= 'root'
      when 'winrm'
        req['ssl'] = false
        req['port'] ||= 5985
      end

      req
    end

    def make_client(uri = nil)
      uri = URI(uri || config_data['file-server-uri'])
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      https.ssl_version = :TLSv1_2
      https.ca_file = config_data['ssl-ca-cert']
      https.cert = OpenSSL::X509::Certificate.new(File.read(config_data['ssl-cert']))
      https.key = OpenSSL::PKey::RSA.new(File.read(config_data['ssl-key']))
      https.verify_mode = OpenSSL::SSL::VERIFY_PEER
      https
    end

    def puppet_server_get(path, params)
      uri = URI("#{config_data['file-server-uri']}#{path}")
      uri.query = URI.encode_www_form(params)
      resp = make_client.request(Net::HTTP::Get.new(uri))
      resp
    end

    def get_task_data(task)
      module_name, file_name = task.split('::')
      file_name ||= 'init'
      path = "/puppet/v3/tasks/#{module_name}/#{file_name}"
      params = { environment: "production" }
      resp = puppet_server_get(path, params)
      unless resp.code == '200'
        raise "request #{path} #{params} failed with: #{resp.body}"
      end
      JSON.parse(resp.body)
    end

    def build_request(task_name, target, params = {})
      {
        'task' => get_task_data(task_name),
        'target' => target2request(target),
        'parameters' => params
      }
    end
  end
end
