module OsCtld
  module Commands
    module Container ; end
    module User ; end
  end
  module Routing ; end
  module Script
    module Container ; end
  end
  module Utils ; end
  module UserControl ; end
  module UserCommands ; end

  POOL = 'lxc'
  USER_DS = "#{POOL}/user"

  def self.root
    File.join(File.dirname(__FILE__), '..')
  end

  def self.bin(name)
    File.absolute_path(File.join(root, 'bin', name))
  end

  def self.hook_src(name)
    File.absolute_path(File.join(root, 'hooks', name))
  end

  def self.hook_run(name)
    File.join(RunState::HOOKDIR, name)
  end

  def self.script(name)
    File.absolute_path(File.join(root, 'scripts', name))
  end

  def self.tpl(name)
    File.absolute_path(File.join(root, 'templates', "#{name}.erb"))
  end
end

require_relative 'osctld/version'
require_relative 'osctld/template'
require_relative 'osctld/lockable'
require_relative 'osctld/object_list'
require_relative 'osctld/run_state'
require_relative 'osctld/utils/log'
require_relative 'osctld/utils/system'
require_relative 'osctld/utils/zfs'
require_relative 'osctld/utils/switch_user'
require_relative 'osctld/utils/ip'
require_relative 'osctld/script'
require_relative 'osctld/script/container/network'
require_relative 'osctld/user_control/client_handler'
require_relative 'osctld/user_control/server'
require_relative 'osctld/user_control/supervisor'
require_relative 'osctld/user_control'
require_relative 'osctld/command'
require_relative 'osctld/user_command'
require_relative 'osctld/client_handler'
require_relative 'osctld/container_list'
require_relative 'osctld/container'
require_relative 'osctld/user_list'
require_relative 'osctld/user'
require_relative 'osctld/routing/via'
require_relative 'osctld/routing/via_ipv4'
require_relative 'osctld/routing/via_ipv6'
require_relative 'osctld/routing/router'
require_relative 'osctld/daemon'
require_relative 'osctld/switch_user'
require_relative 'osctld/switch_user/container_control'

require_relative 'osctld/commands/base'
Dir.glob(File.join(
  File.dirname(__FILE__),
  'osctld', 'commands', '*', '*.rb'
)).each { |f| require_relative f }

require_relative 'osctld/user_commands/base'
Dir.glob(File.join(
  File.dirname(__FILE__),
  'osctld', 'user_commands', '*.rb'
)).each { |f| require_relative f }
