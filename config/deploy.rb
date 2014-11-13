# config valid only for Capistrano 3.1
lock '3.2.1'

set :application, 'hub'
set :repo_url, 'git@github.com:instedd/hub.git'
set :deploy_to, '/u/apps/hub'
set :bundle_jobs, 8

set :rvm_type, :system
set :rvm_ruby_version, '2.1.3'

set :hosts, ENV["HOSTS"] || fail("HOSTS must be specified")

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

set :linked_files, %w{config/database.yml config/secrets.yml config/guisso.yml config/newrelic.yml config/poirot.yml}
set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

namespace :deploy do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

end

namespace :foreman do
  desc 'Export the Procfile to Ubuntu upstart scripts'
  task :export do
    on roles(:app) do
      within current_path do
        execute :echo, "RAILS_ENV=production > .env"
        %w(PATH GEM_HOME GEM_PATH).each do |var|
          execute :rvm, %(#{fetch(:rvm_ruby_version)} do ruby -e 'puts "#{var}=\#{ENV["#{var}"]}"' >> .env)
        end
        execute :bundle, "exec rvmsudo foreman export upstart /etc/init -f Procfile -a #{fetch(:application)} -u `whoami` --concurrency=\"resque=1,resque-scheduler=1\""
      end
    end
  end

  desc "Start the application services"
  task :start do
    on roles(:app) do
      sudo "start #{fetch(:application)}"
    end
  end

  desc "Stop the application services"
  task :stop do
    on roles(:app) do
      sudo "stop #{fetch(:application)}"
    end
  end

  desc "Restart the application services"
  task :restart do
    on roles(:app) do
      execute "sudo start #{fetch(:application)} || sudo restart #{fetch(:application)}"
    end
  end

  after 'deploy:publishing', 'foreman:export'
  after 'deploy:restart', 'foreman:restart'
end
