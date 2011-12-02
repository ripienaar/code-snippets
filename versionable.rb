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
    if is_a?(Class)
      api_register(version, klass, &block)
    else
      self.class.api_register(version, klass, &block)
    end
  end

  def api_send(version, method, *args)
    @api_impl[version].send(method, *args)
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

class Foo
  extend Versionable
  include Versionable

  class V3
    def initialize(foo)
      @foo = foo
    end

    def do_it(msg)
      puts "version 3 got '#{msg['message']}' foo is #{@foo}"
    end
  end

  # 2 versions of the do_it method inline in the same class
  version 1 do
    def do_it(msg)
      puts "version 1 got '#{msg}'"
    end
  end

  version 2 do
    def do_it(msg)
      puts "version 2 got '#{msg[:msg]}'"
    end
  end

  def initialize(foo)
    # version 3 is special, it needs args passed to it specially etc,
    # not a problem you can set it up here and the #do_it method will be
    # proxied correctly
    version 3, V3.new(foo)
  end

  # a method that once just took a string and now takes
  # a hash that has a version identifier in it
  def do_it(msg)
    version = (msg[:v] || 1) rescue 1

    versioned_send(version, :do_it, msg)
  end
end

# Inheritance works - no versions are inherited just
# the proper methods so a API can just inherit from the
# API base class and do the version jig
class Bar<Foo
  def initialize; end

  version 1 do
    def do_it(msg)
      puts "Bar version 1 got '#{msg}'"
    end
  end
end

# instance of my class and talk to 3 different versions of its do_it method
f = Foo.new("meh")
f.do_it("version 1")
f.do_it(:msg => "version 2", :v => 2)
f.do_it("message" => "version 3", :v => 3)

b = Bar.new
b.do_it "hello"

# these will both fail saying it cant find the version in the api
f.do_it("message" => "version 4", :v => 4) rescue puts $!
b.do_it(:msg => "version 2", :v => 2) rescue puts $!
