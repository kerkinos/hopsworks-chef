
notifying_action :restart do

bash "restart_domain1" do
   user "root"
   ignore_failure true
   code <<-EOF
    service glassfish restart
  EOF
end

end


notifying_action :alter_tables do

exec = "#{node[:ndb][:scripts_dir]}/mysql-client.sh"
cached_hopsworksmgr_filename = "#{Chef::Config[:file_cache_path]}/hopsworks.war"

bash "redeploy_app_to_create_tables" do
  user node[:glassfish][:user]
  group node[:glassfish][:group]
   code <<-EOF
   #{node[:glassfish][:base_dir]}/glassfish/bin/asadmin --user admin --passwordfile #{node[:glassfish][:domains_dir]}/domain1_admin_passwd undeploy hopsworks 
   #{node[:glassfish][:base_dir]}/glassfish/bin/asadmin --user admin --passwordfile #{node[:glassfish][:domains_dir]}/domain1_admin_passwd deploy --enabled=true --upload=true --availabilityenabled=true --verify=true --force=true --name hopsworks #{cached_hopsworksmgr_filename}
  EOF
    not_if "#{exec} hopsworks \"show tables\" | grep -i Alerts"
end

bash "alter_table_to_ndb" do
   user "root"
   code <<-EOF

   #{exec} hopsworks -e \"source #{new_resource.alter_path}\"
  EOF
    not_if "#{exec} hopsworks \"show create table users;\" | grep -i ndbcluster"
end


end
