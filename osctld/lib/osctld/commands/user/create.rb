require 'osctld/commands/logged'

require 'fileutils'

module OsCtld
  class Commands::User::Create < Commands::Logged
    handle :user_create

    include OsCtl::Lib::Utils::Log
    include OsCtl::Lib::Utils::System

    def find
      pool = DB::Pools.get_or_default(opts[:pool])
      error!('pool not found') unless pool

      rx = /^[a-z0-9_-]{1,29}$/

      if rx !~ opts[:name]
        error!("invalid name, allowed format: #{rx.source}")

      elsif opts[:ugid] < 1
        error!('invalid ugid: must be greater than 0')

      elsif !opts[:uid_map] || opts[:uid_map].empty?
        error!('missing UID map')

      elsif !opts[:gid_map] || opts[:gid_map].empty?
        error!('missing GID map')
      end

      # Check for duplicities
      if u = DB::Users.by_ugid(opts[:ugid])
        error!(
          "ugid #{opts[:ugid]} already taken by user "+
          "#{u.pool.name}:#{u.name}"
        )

      elsif u = DB::Users.by_name(opts[:name])
        error!(
          "name #{opts[:ugid]} already taken by user "+
          "#{u.pool.name}:#{u.name}"
        )
      end

      # Check UID/GID maps
      uid_map = IdMap.load(opts[:uid_map])
      gid_map = IdMap.load(opts[:gid_map])

      if !uid_map.valid?
        error!('UID map is not valid')

      elsif !gid_map.valid?
        error!('GID map is not valid')
      end

      u = User.new(pool, opts[:name], load: false)
      error!('user already exists') if DB::Users.contains?(u.name, pool)
      u
    end

    def execute(u)
      manipulate(u) do
        zfs(:create, nil, u.dataset)

        File.chown(0, opts[:ugid], u.userdir)
        File.chmod(0751, u.userdir)

        Dir.mkdir(u.homedir) unless Dir.exist?(u.homedir)
        File.chown(opts[:ugid], opts[:ugid], u.homedir)
        File.chmod(0751, u.homedir)

        u.configure(opts[:ugid], opts[:uid_map], opts[:gid_map])
        DB::Users.add(u)
        UserControl::Supervisor.start_server(u)

        call_cmd!(Commands::User::Register, name: u.name, pool: u.pool.name)
        call_cmd!(Commands::User::SubUGIds)
      end

      ok
    end
  end
end
