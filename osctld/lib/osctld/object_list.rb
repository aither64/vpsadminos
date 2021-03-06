require 'thread'

module OsCtld
  # Thread-safe singleton object list
  class ObjectList
    @@instances = {}

    class << self
      def instance
        @@instances[self] = new unless @@instances.has_key?(self)
        @@instances[self]
      end

      %i(sync get add remove find contains?).each do |v|
        define_method(v) do |*args, &block|
          instance.send(v, *args, &block)
        end
      end
    end

    private
    def initialize
      @mutex = Mutex.new
      @objects = []
    end

    public
    def sync(&block)
      if @mutex.owned?
        block.call
      else
        @mutex.synchronize { block.call }
      end
    end

    def get(&block)
      sync do
        if block
          block.call(@objects)
        else
          @objects.clone
        end
      end
    end

    def add(obj)
      sync do
        if @objects.detect { |v| v.id == obj.id }
          raise "#{obj.id} already is in #{self.class.name}"
        end

        @objects << obj
      end
    end

    def remove(obj)
      sync { @objects.delete(obj) }
    end

    def find(id, &block)
      sync do
        obj = @objects.detect { |v| v.id == id }

        if block
          block.call(obj)
        else
          obj
        end
      end
    end

    def contains?(id)
      !find(id).nil?
    end
  end
end
