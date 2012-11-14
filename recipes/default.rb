#
# Cookbook Name:: drupal
# Recipe:: default
#
# Copyright 2009-2010, Skystack, Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

node["sites"].each do |site|

  application_set = site['config']['set']
  webserver = site['config']['webserver']
  
  node["databases"].each do |db|
    if db['config']['set'] == application_set
      site['database'] = db
    end
  end

node.set['drupal']['database_user'] = site['database']['user']
node.set['drupal']['database_password'] =  site['database']['password']
node.set['drupal']['database'] =  site['database']['name']
node.set['drupal']['salt'] = secure_password

site_fqdn = site['server_name']
site_dir = site['document_root']

  if node['drupal']['version'] == 'latest'
  	version = node['drupal']['latest']
  	node.set['drupal']['version'] = node['drupal']['latest']
    # drupal.org does not provide a sha256 checksum, so we'll use the sha1 they do provide
    require 'digest/sha1'
    require 'open-uri'
    local_file = "#{Chef::Config[:file_cache_path]}/drupal-#{version}.tar.gz"

    unless File.exists?(local_file)
      remote_file "#{Chef::Config[:file_cache_path]}/drupal-#{version}.tar.gz" do
        source "http://ftp.drupal.org/files/projects/drupal-#{version}.tar.gz"
        mode "0644"
        action :create_if_missing
      end
    end
  else
    remote_file "#{Chef::Config[:file_cache_path]}/drupal-#{node['drupal']['version']}.tar.gz" do
      source "http://ftp.drupal.org/files/projects/drupal-#{node['drupal']['version']}.tar.gz"
      mode "0644"
    end
  end

  directory "#{site_dir}" do
    owner "root"
    group "root"
    mode "0755"
    action :create
    recursive true
  end

  execute "untar-drupal" do
    cwd site_dir
    command "tar --strip-components 1 -xzf #{Chef::Config[:file_cache_path]}/drupal-#{node['drupal']['version']}.tar.gz"
    creates "#{site_dir}/install.php"
  end

  template "#{site_dir}/sites/default/settings.php" do
    source "settings.php.erb"
    owner "root"
    group "root"
    mode "0644"
    variables(
      :host            => node['drupal']['database_host'],
      :database        => node['drupal']['database'],
      :user            => node['drupal']['database_user'],
      :password        => node['drupal']['database_password'],
      :salt            => node['drupal']['salt']
    )
    notifies :write, "log[Navigate to 'http://#{site_fqdn}/install.php' to complete drupal installation]"
  end


  log "Navigate to 'http://#{site_fqdn}/install.php' to complete drupal installation" do
    action :nothing
  end

  service webserver do
    action :restart
  end

end



