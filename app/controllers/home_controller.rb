require 'csv' 

class HomeController < ApplicationController
  before_filter :get_data, only: [ :index ] 

  def index 
  end 

  def export_to_csv 
    @@data ||= get_data       
    csv_string = CSV.generate do |csv|
      csv << [
              'Role', 'Fqdn', 'Ip', 'Cluster name', 'Shard name',
              'Priority', 'Component to balance', 'Balanced FQDNs'
             ]
      @@data.nodes_by_role.each do |role,nodes|
        nodes.each do |node|
          csv << [
                  role, node.hostname, node.ip, node.cluster_name, 
                  node.shard_name, node.balance_component, node.balanced_fqdns
                 ]
        end
      end
    end    

    headers = {
      type: 'text/csv; charset=iso-8859-1; header=present',
      disposition: "attachment; filename=nodes_#{@@data.env}.csv"
    }

    send_data(csv_string, headers)
  end 

  private 
    def get_data 
      @data = EndPoint.new 
      @data.get_topology
      @@data = @data 
    end 
end
