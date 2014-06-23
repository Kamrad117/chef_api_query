require 'csv' 

class HomeController < ApplicationController
  before_filter :get_data, only: [ :index ] 

  def index 
  end 

  def export_to_csv 
    @@data ||= get_data       
    csv_string = CSV.generate do |csv|
      csv << [
              'Role', 'Fqdn', 'Ip', 'Cluster_name', 
              'Shard_name', 'Component_to_balance'
             ]
      @@data.nodes_by_role.each do |role,nodes|
        nodes.each do |node|
          csv << [
                  role, node.hostname, node.ip, node.cluster_name, 
                  node.shard_name, node.balance_component
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
