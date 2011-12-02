# A simple Mixin that allows methods
# to have multiple versioned implementations
# on a single class
module Versionable
  class Container
    def self.hide(name)
      if instance_methods.include?(name.to_s) and
        name !~ /^(__|instance_eval|send)/
        undef_method name
      end
    end

    # blank slate
    instance_methods.each { |m| hide(m) }
  end

  def versioned_send(version, method, *args)
    raise "Don't have a verion #{version} of the method #{method}" unless self.class.api_has_version?(version)

    self.class.api_send(version, method, *args)
  end

  def version(version, klass=nil, &block)
    api_register(version, klass, &block)
  end

  def api_send(version, method, *args)
    @api_impl[version].send(method, args)
  end

  def api_has_version?(version)
    !!@api_impl[version]
  end

  def api_register(version, klass, &block)
    @api_impl ||= {}

    if klass
      @api_impl[version] = klass
    else
      @api_impl[version] = Container.new
      @api_impl[version].instance_eval(&block) if block_given?
    end
  end
end

class V3
  def do_it(msg)
    puts "version 3 got #{msg.inspect}"
  end
end

class Foo
  extend Versionable
  include Versionable

  version 1 do
    def do_it(msg)
      puts "version 1 got #{msg.inspect}"
    end
  end

  version 2 do
    def do_it(msg)
      puts "version 2 got #{msg.inspect}"
    end
  end

  version 3, V3.new

  # a method that once just took a string and now takes
  # a hash that has a version identifier in it
  def do_it(msg)
    version = (msg[:v] || 1) rescue 1

    versioned_send(version, :do_it, msg)
  end
end

f = Foo.new
f.do_it("version 1 string")
f.do_it({:v => 2, :msg => "version 2 hash"})
f.do_it({:v => 3, :msg => "version 3 hash"})
f.do_it({:v => 4, :msg => "version 4 hash"})
