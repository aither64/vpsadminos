module OsCtl::Cli
  class Pool < Command
    FIELDS = %i(
      name
      dataset
      users
      groups
      containers
    )

    DEFAULT_FIELDS = FIELDS

    def list
      if opts[:list]
        puts FIELDS.join("\n")
        return
      end

      cmd_opts = {}
      fmt_opts = {layout: :columns}

      cmd_opts[:names] = args if args.count > 0
      fmt_opts[:header] = false if opts['hide-header']

      osctld_fmt(
        :pool_list,
        cmd_opts,
        opts[:output] ? opts[:output].split(',').map(&:to_sym) : DEFAULT_FIELDS,
        fmt_opts
      )
    end

    def import
      if !args[0] && !opts[:all]
        raise GLI::BadCommandLine, 'specify pool name or --all'
      end

      osctld_fmt(:pool_import, name: args[0], all: opts[:all])
    end

    def export
      require_args!('name')
      osctld_fmt(:pool_export, name: args[0])
    end

    def install
      require_args!('name')

      cmd_opts = {name: args[0]}
      cmd_opts[:dataset] = opts[:dataset] if opts[:dataset]

      osctld_fmt(:pool_install, cmd_opts)
    end

    def uninstall
      require_args!('name')
      osctld_fmt(:pool_uninstall, name: args[0])
    end
  end
end