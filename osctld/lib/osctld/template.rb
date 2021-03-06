require 'erb'

module OsCtld
  class Template
    def self.render(name, vars)
      t = new(name, vars)
      t.render
    end

    def self.render_to(name, vars, path)
      File.write("#{path}.new", render(name, vars))
      File.rename("#{path}.new", path)
    end

    def initialize(name, vars)
      @_tpl = ERB.new(File.new(OsCtld.tpl(name)).read, 0, '-')

      vars.each do |k, v|
        define_singleton_method(k) { v }
      end
    end

    def render
      @_tpl.result(binding)
    end
  end
end
