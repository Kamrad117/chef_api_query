require 'chef'
require 'thread/channel'
require 'parallel'
require 'pry-rails'
require 'net/ssh'
require 'net/scp'
require 'yaml'

class EndPoint
  attr_accessor :env, :nodes_by_role, :nodes_without_role, :nodes_without_env
  def initialize
    # @connection = Chef::REST.new(*credentials.values)
    Chef::Config.from_file("/home/kamrad/.chef/knife.rb")
    @connection = Chef::REST.new('https://hwd1-tchain02.swlab.rmscloud.net:4040')
    @env = 'SWDEV04'
    @nodes_by_role, @nodes_without_role,@nodes_without_env = {}, [], []
  end

  # def credentials 
  #   {
  #     chef_server_url: 'https://hwd1-tchain02.swlab.rmscloud.net:4040', 
  #     client_name: 'cengint-toolchain.swlab.rmscloud.net', 
  #     signing_key_filename: "lib/client.pem"
  #   }
  # end

  def create_node(node_name)
    node_hash = @connection.get_rest("nodes/#{node_name}")

    node = OpenStruct.new( {
      hostname:           node_hash.deep_find(:fqdn),
      chef_env:           node_hash.deep_find(:chef_environment),
      os:                 node_hash.deep_find(:os),
      roles:              node_hash.deep_find(:roles),
      ip:                 node_hash.deep_find(:ipaddress),
      filesystem:         node_hash.deep_find(:filesystem),
    } )

    if node.roles && node.roles.any? && node.roles.any? { |r| r.include?('rms_ha') }
      node.balance_component = node_hash.attribute.haproxy.component_to_balance
    end

    node = set_mongo_attributes(node, node_hash)
    node
  end

  def get_topology 
    nodes = @connection.get_rest('nodes/')

    Parallel.each(nodes.keys, in_threads: 40)  do |node_name|
      node = create_node(node_name)
      begin
        if [nil, '', [], [''], [nil]].include?(node.roles) 
          @nodes_without_role << node 
        elsif node.chef_env == nil 
          @nodes_without_env << node        
        elsif node.chef_env.include?(@env)
          node.roles.each do |role|
            if role.include?("rms_")
              if @nodes_by_role.has_key?(role)
                @nodes_by_role[role] << node
              else
                @nodes_by_role[role] = [node]
              end
            end
          end
        end
      rescue StandardError => e
        puts e.message 
        puts e.class
      end
    end
  end

  def set_mongo_attributes(node, node_hash)
    if node.roles && node.roles.any? && node.roles.any? { |r| r[/rms_mg[bcdor]{1}/] }
      node.cluster_name = node_hash.attribute.mongodb.cluster_name 
      node.shard_name = node_hash.attribute.mongodb.shard_name 
      if node.roles.any? { |r| r[/rms_mg[bcdor]{1}rpl/] }
        rpl_json = Net::SSH.start(node.ip, 'svc-kefchef', password: 'u78s#V5!SmpS') do |ssh|
          ssh.exec!("mongo --quiet --eval 'printjson(rs.status())'")
        end
        # rpl_json
        # binding.pry
      end
      node 
    end
  end

  def group_by_common_attributes

  end
end

class Hash
  def deep_find(key)
    key?(key) ? self[key] : self.values.inject(nil) {|memo, v| memo ||= v.deep_find(:key) if v.respond_to?(:deep_find) }
  end
end
