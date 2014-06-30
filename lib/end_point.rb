require 'chef'
require 'thread/channel'
require 'parallel'
require 'net/ssh'
require 'net/scp'
require 'yaml'
require 'mongo'

class EndPoint
  attr_accessor :env, :nodes_by_role, :nodes_without_role, :nodes_without_env
  def initialize
    Chef::Config.from_file("#{ENV['HOME']}/.chef/knife.rb")
    @connection = Chef::REST.new(Chef::Config[:chef_server_url])
    @env = 'SWDEV04'
    @nodes_by_role, @nodes_without_role,@nodes_without_env = {}, [], []
  end

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

    begin
      p "======================================================"
      Parallel.each(nodes.keys, in_threads: 40)  do |node_name|
      node = create_node(node_name)
        if [nil, '', [], [''], [nil]].include?(node.roles) 
          @nodes_without_role << node 
        elsif node.chef_env == nil 
          @nodes_without_env << node        
        elsif node.chef_env.include?(@env)
          node.roles.each do |role|
            add_node(node, role) if role.include?("rms_")
          end
        end
      end
    rescue StandardError => e
      e.message 
      puts e.class
    end
    set_balanced_fqdns
  end

  def add_node(node, role)
    p node.hostname 
    if @nodes_by_role.keys.include?(role)
      @nodes_by_role[role].each do |old_node|
        if nodes_similar?(old_node, node)
          old_node = merge_nodes(old_node, node)
        else 
          @nodes_by_role[role] << node
        end
      end
    else 
      @nodes_by_role[role] = [node]
    end
  end

  def nodes_similar?(old_node, node)
    old_node.balance_component == node.balance_component &&
    old_node.balance_fqdns == node.balance_fqdns &&
    old_node.cluster_name == node.cluster_name &&
    old_node.shard_name == node.shard_name && 
    old_node.priority == node.priority &&
    old_node.hostname != node.hostname
  end

  def merge_nodes(old_node, node)
    old_node.hostname += " #{node.hostname}"
    old_node.ip += " #{node.ip}"
  end

  def set_balanced_fqdns 
    @nodes_by_role.each do |role, nodes|
      if role.include?('rms_ha')
        node = nodes.first 
        p nodes.first.balance_fqdns = @nodes_by_role["rms_#{node.balance_component.downcase}"].first.hostname
      end
    end
  end

  def set_mongo_attributes(node, node_hash)
    if node.roles && node.roles.any? && node.roles.any? { |r| r[/rms_mg[bcdor]{1}/] }
      node.cluster_name = node_hash.attribute.mongodb.cluster_name 
      node.shard_name = node_hash.attribute.mongodb.shard_name 
      if node.roles.any? { |r| r[/rms_mg[bcdor]{1}rpl/] }
        begin
          node.priority = if Mongo::MongoClient.new(node.ip, 27017).primary?
            'Primary'
          else 
            'Secondary'
          end 
        rescue StandardError => e
          node.priority = 'Got error'
          puts e 
        end
      end
    end
    node 
  end
end

class Hash
  def deep_find(key)
    key?(key) ? self[key] : self.values.inject(nil) {|memo, v| memo ||= v.deep_find(:key) if v.respond_to?(:deep_find) }
  end
end
