use_inline_resources

notifying_action :create_tables do
  Chef::Log.info("Tables.sql is here: #{new_resource.tables_path}")
  db="hopsworks"
  exec = "#{node[:ndb][:scripts_dir]}/mysql-client.sh"

  bash 'create_hopsworks_tables' do
    user "root"
    code <<-EOF
      #{exec} -e \"CREATE DATABASE IF NOT EXISTS hopsworks CHARACTER SET latin1 COLLATE latin1_swedish_ci\"
      #{exec} -e \"CREATE DATABASE IF NOT EXISTS glassfish_timers CHARACTER SET latin1 COLLATE latin1_swedish_ci\"
      #{exec} #{db} -e \"source #{new_resource.tables_path}\"
    EOF
    not_if "#{exec} #{db} < \"show tables;\" | grep bbc_group"
  end

end

notifying_action :insert_rows do
  Chef::Log.info("Rows.sql is here: #{new_resource.rows_path}")
  exec = "#{node[:ndb][:scripts_dir]}/mysql-client.sh"
  timerTable = "ejbtimer_mysql.sql"
  timerTablePath = "#{Chef::Config[:file_cache_path]}/#{timerTable}"

 template timerTablePath do
    source "#{timerTable}.erb"
    owner node[:glassfish][:user]
    mode 0750
    action :create
  end 

  bash 'insert_hopsworks_rows' do
    user "root"
    code <<-EOF
      set -e
      #{exec} hopsworks -e \"set foreign_key_checks=0; source #{new_resource.rows_path}\"
      #{exec} glassfish_timers -e \"source #{timerTablePath}"
    EOF
    not_if "#{exec} hopsworks < \"select email from users;\" | grep admin"
  end
end

notifying_action :sshkeys do
  # Set attribute for dashboard's public_key to the ssh public key
  key=IO.readlines("#{node['glassfish']['base_dir']}/.ssh/id_rsa.pub").first
  node.normal[:hopsworks][:public_key]=key.gsub("\n","")
end
