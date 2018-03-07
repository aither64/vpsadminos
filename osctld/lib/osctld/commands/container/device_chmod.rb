module OsCtld
  class Commands::Container::DeviceChmod < Commands::Logged
    handle :ct_device_chmod

    include OsCtl::Lib::Utils::Log
    include Utils::Devices

    def find
      ct = DB::Containers.find(opts[:id], opts[:pool])
      ct || error!('container not found')
    end

    def execute(ct)
      ct.exclusively do
        chmod(ct, ct.group)
      end
    end
  end
end