require 'filelock'

module OsCtl::Repo
  class Remote::Template < Base::Template
    def abs_rootfs_url(format)
      File.join(repo.url, rootfs_path(format))
    end

    def cached?(format)
      File.exist?(abs_rootfs_path(format))
    end

    def lock(format)
      Filelock(
        File.join(abs_dir_path, ".#{rootfs_name(format)}.lock"),
        timeout: 60*60
      ) { yield }
    end
  end
end