require 'socket'

module OsCtld
  class Daemon
    include Utils::Log
    include Utils::System
    include Utils::Zfs

    SOCKET = File.join(RunState::RUNDIR, 'osctld.sock')

    def initialize
      Thread.abort_on_exception = true
      UserList.instance
      ContainerList.instance
      Routing::Router.instance
    end

    def setup
      # Setup /run/osctl
      RunState.create

      # Ensure needed datasets are present
      mkdatasets

      # Load users from zpool
      load_users

      # Register loaded users into the system
      Commands::User::Register.run(all: true)

      # Generate /etc/subuid and /etc/subgid
      Commands::User::SubUGIds.run

      # Load containers from zpool
      load_cts

      # Allow containers to create veth interfaces
      Commands::User::LxcUsernet.run

      # Configure container router
      Routing::Router.setup

      # Start user control server, used for lxc hooks
      UserControl.setup

      # Start accepting client commands
      serve
    end

    def mkdatasets
      log(:info, :init, "Ensuring presence of dataset #{USER_DS}")
      zfs(:create, '-p', USER_DS)
    end

    def load_users
      log(:info, :init, "Loading users from data pool")

      out = zfs(:list, '-H -r -t filesystem -d 1 -o name', USER_DS)[:output]

      out.split("\n")[1..-1].map do |line|
        UserList.add(User.new(line.strip.split('/').last))
      end
    end

    def load_cts
      log(:info, :init, "Loading containers from data pool")

      state = ContainerList.load_state
      out = zfs(:list, '-H -r -t filesystem -d 3 -o name', USER_DS)[:output]

      out.split("\n").map do |line|
        parts = line.strip.split('/')

        # lxc/user/<user>/ct/<id>
        next if parts.count < 5

        user = parts[2]
        ctid = parts[4]

        ct = Container.new(ctid, user)

        if state.has_key?(ct.id)
          ct.veth = state[ct.id]['veth']
        end

        ContainerList.add(ct)
      end
    end

    def serve
      log(:info, :init, "Listening on control socket at #{SOCKET}")

      @srv = UNIXServer.new(SOCKET)
      File.chmod(0600, SOCKET)

      loop do
        begin
          c = @srv.accept

        rescue IOError
          return

        else
          handle_client(c)
        end
      end
    end

    def stop
      log(:info, :daemon, "Exiting")
      @srv.close if @srv
      File.unlink(SOCKET) if File.exist?(SOCKET)
      UserControl.stop
      exit(false)
    end

    private
    def handle_client(client)
      log(:info, :server, 'Received a new client connection')

      Thread.new do
        c = ClientHandler.new(client)
        c.communicate
      end
    end
  end
end
