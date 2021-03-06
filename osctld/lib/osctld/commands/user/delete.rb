module OsCtld
  class Commands::User::Delete < Commands::Base
    handle :user_delete

    def execute
      UserList.sync do
        u = UserList.find(opts[:name])
        return error('user not found') unless u
        return error('user has container(s)') if u.has_containers?

        UserControl::Supervisor.stop_server(u)

        u.exclusively do
          # Double-check user's containers, for only within the lock
          # can we be sure
          return error('user has container(s)') if u.has_containers?
          u.delete
        end

        UserList.remove(u)
        call_cmd(Commands::User::SubUGIds)
      end

      ok
    end
  end
end
