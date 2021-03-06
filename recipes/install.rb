
node.override[:glassfish][:user] = node[:hopsworks][:user]

username=node[:hopsworks][:admin][:user]
password=node[:hopsworks][:admin][:password]
domain_name="domain1"
domains_dir = node[:glassfish][:domains_dir]
admin_port = node[:glassfish][:admin][:port]
web_port = node[:glassfish][:port]
mysql_user=node[:mysql][:user]
mysql_password=node[:mysql][:password]
mysql_host = private_recipe_ip("ndb","mysqld")


node.override = {
  'java' => {
    'install_flavor' => 'oracle',
    'jdk_version' => 7,
    'oracle' => {
      'accept_oracle_download_terms' => true
    }
  },
  'glassfish' => {
    'version' => node[:glassfish][:version],
    'base_dir' => node[:glassfish][:base_dir],
    'domains_dir' => domains_dir,
    'domains' => {
      domain_name => {
        'config' => {
          'min_memory' => node[:glassfish][:min_mem],
          'max_memory' => node[:glassfish][:max_mem],
          'max_perm_size' => node[:glassfish][:max_perm_size],
          'port' => web_port,
          'admin_port' => admin_port,
          'username' => username,
          'password' => password,
          'master_password' => node[:hopsworks][:master][:password],
          'remote_access' => false,
          'jvm_options' => ['-DHADOOP_DIR=/srv/hadoop', '-Dcom.sun.enterprise.tools.admingui.NO_NETWORK=true'],
          'secure' => false
        },
        'extra_libraries' => {
          'jdbcdriver' => {
            'type' => 'common',
            'url' => node[:hopsworks][:mysql_connector_url]
          }
        },
        'threadpools' => {
          'thread-pool-1' => {
            'maxthreadpoolsize' => 200,
            'minthreadpoolsize' => 5,
            'idletimeout' => 900,
            'maxqueuesize' => 4096
          },
          'http-thread-pool' => {
            'maxthreadpoolsize' => 200,
            'minthreadpoolsize' => 5,
            'idletimeout' => 900,
            'maxqueuesize' => 4096
          },
          'admin-pool' => {
            'maxthreadpoolsize' => 50,
            'minthreadpoolsize' => 5,
            'maxqueuesize' => 256
          }
        },
        # 'iiop_listeners' => {
        #   'orb-listener-1' => {
        #     'enabled' => true,
        #     'iiopport' => 1072,
        #     'securityenabled' => false
        #   }
        # },
        'jdbc_connection_pools' => {
          'hopsworksPool' => {
            'config' => {
              'datasourceclassname' => 'com.mysql.jdbc.jdbc2.optional.MysqlDataSource',
              'restype' => 'javax.sql.DataSource',
              'isconnectvalidatereq' => 'true',
              'validationmethod' => 'auto-commit',
              'ping' => 'true',
              'description' => 'Hopsworks Connection Pool',
              'properties' => {
                'Url' => "jdbc:mysql://#{mysql_host}:3306/",
                'User' => mysql_user,
                'Password' => mysql_password
              }
            },
            'resources' => {
              'jdbc/hopsworks' => {
                'description' => 'Resource for Hopsworks Pool',
              }
            }
          },
          'ejbTimerPool' => {
            'config' => {
              'datasourceclassname' => 'com.mysql.jdbc.jdbc2.optional.MysqlDataSource',
              'restype' => 'javax.sql.DataSource',
              'isconnectvalidatereq' => 'true',
              'validationmethod' => 'auto-commit',
              'ping' => 'true',
              'description' => 'Hopsworks Connection Pool',
              'properties' => {
                'Url' => "jdbc:mysql://#{mysql_host}:3306/glassfish_timers",
                'User' => mysql_user,
                'Password' => mysql_password
              }
            },
            'resources' => {
              'jdbc/hopsworksTimers' => {
                'description' => 'Resource for Hopsworks EJB Timers Pool',
              }
            }
          }
        }
      }
    }
  }
}
installed = "#{node[:glassfish][:base_dir]}/.installed"
if ::File.exists?( "#{installed}" ) == false || "#{node[:hopsworks][:reinstall]}" == "true" 

if "#{node[:hopsworks][:reinstall]}" == "true" 
   directory node[:glassfish][:base_dir] do
     owner node[:glassfish][:user]
     group node[:glassfish][:group]
     action :delete
     recursive true
   end
end


  include_recipe 'glassfish::default'
  include_recipe 'glassfish::attribute_driven_domain'

  file "#{installed}" do # Mark that glassfish is installed
    owner node[:glassfish][:user]
  end

cauth = File.basename(node[:glassfish][:cauth_url])

remote_file "#{node[:glassfish][:domains_dir]}/#{domain_name}/lib/#{cauth}"  do
  user node[:glassfish][:user]
  group node[:glassfish][:group]
  source node[:glassfish][:cauth_url]
  mode 0755
  action :create_if_missing
end



end

#
# This code is to enable ssh access
#

node.default['authorization']['sudo']['include_sudoers_d'] = true
node.default['authorization']['sudo']['passwordless'] = true

include_recipe 'sudo'

sudo 'glassfish' do
  user    node[:glassfish][:user]
  commands  ['/srv/mkuser.sh', '/usr/sbin/deluser', '/usr/mount', '/usr/umount']
  nopasswd   true
end



# Hack for cuneiform that expects that the username has a /home/username directory.

directory "/home/#{node[:glassfish][:user]}/software" do
  owner node[:glassfish][:user]
  group node[:glassfish][:group]
  mode "755"
  action :create
  recursive true
end

