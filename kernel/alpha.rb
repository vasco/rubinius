#
# This is the beginning of loading Ruby code. At this point, the VM
# is bootstrapped and the fundamental data structures, primitive
# functions and the basic classes and objects are available.
#
# The classes, modules, and methods defined here provide basic
# functionality needed to load the bootstrap directory. By the
# end of this file, the following methods are available:
#
#   attr_reader :sym
#   attr_writer :sym
#   attr_accessor :sym
#
#   private :sym
#   protected :sym
#
#   module_function :sym
#
# These forms should be used in the rest of the kernel. In delta,
# more complete forms of these methods are provided for user code.
#
# NOTE: The order of these definitions is important. Do not
#       change it without consultation.


# Hook called when class created or reopened.
#
def opened_class(created)
  # No default behaviour.
end


# This class encapsulates primitives that involve the VM
# itself rather than something in Ruby-land.
#
# See kernel/bootstrap/vm.rb
#
class Rubinius::VM

  # Write given string to stderr.
  #
  # Used to support error reporting where IO is not reliable yet.
  #
  def self.write_error(str)
    Ruby.primitive :vm_write_error
    raise PrimitiveFailure, "Rubinius::VM.write_error primitive failed"
  end

  # Prints Ruby backtrace at point of call.
  #
  def self.show_backtrace
    Ruby.primitive :vm_show_backtrace
    raise PrimitiveFailure, "Rubinius::VM.show_backtrace primitive failed"
  end

  # Reset the method cache globally for given method name.
  #
  def self.reset_method_cache(sym)
    Ruby.primitive :vm_reset_method_cache
    raise PrimitiveFailure, "Rubinius::VM.reset_method_cache primitive failed"
  end
end


class Object
  # Prints basic information about the object to stdout.
  #
  def __show__
    Ruby.primitive :object_show
  end
end


class Class

  # Allocate memory for an instance of the class without initialization.
  #
  # The object returned is valid to use, but its #initialize
  # method has not been called. In almost all cases, .new is
  # the correct method to use instead.
  #
  # See .new
  #
  def allocate
    Ruby.primitive :class_allocate
    raise RuntimeError, "Class#allocate primitive failed on #{self.inspect}"
  end

  # Allocate and initialize an instance of the class.
  #
  # Default implementation: merely allocates the instance, and
  # then calls the #initialize method on the object with the
  # given arguments and block, if provided.
  #
  # See .allocate
  #
  def new(*args)
    obj = allocate()

    Rubinius.asm(args, obj) do |args, obj|
      run obj
      run args
      push_block
      send_with_splat :initialize, 0, true
      # no pop here, as .asm blocks imply a pop as they're not
      # allowed to leak a stack value
    end

    return obj
  end
end


module Kernel

  # Send message to object with given arguments.
  #
  # Ignores visibility of method, and may therefore be used to
  # invoke protected or private methods.
  #
  # As denoted by the double-underscore, this method must not
  # be removed or redefined by user code.
  #
  def __send__(*args)
    Ruby.primitive :object_send
    raise RuntimeError, "Kernel#__send__ primitive failed"
  end

  # Return the Class object this object is an instance of.
  #
  # Note that this method must always be called with an
  # explicit receiver, since class by itself is a keyword.
  #
  def class
    Ruby.primitive :object_class
    raise PrimitiveFailure, "Kernel#class primitive failed."
  end

  # String representation of an object.
  #
  # By default, the representation is the name of the object's
  # class preceded by a # to indicate the object is an instance
  # thereof.
  #
  def to_s
    "#<#{self.class.name}>"
  end

  # :internal:
  #
  # Lowest-level implementation of raise, used internally by
  # kernel code until a more sophisticated version is loaded.
  #
  # Redefined later.
  #
  def raise(cls, str, junk=nil)
    Rubinius::VM.write_error "Fatal error loading runtime kernel:\n  "
    Rubinius::VM.write_error str
    Rubinius::VM.write_error "\n"
    Rubinius::VM.show_backtrace
    Process.exit 1
  end

  # Returns true if the given Class is either the class or superclass of the
  # object or, when given a Module, if the Module has been included in object's
  # class or one of its superclasses. Returns false otherwise.
  #
  # If the argument is not a Class or Module, a TypeError is raised.
  #
  def kind_of?(cls)
    Ruby.primitive :object_kind_of
    raise TypeError, 'kind_of? requires a Class or Module argument'
  end

  # Hook method invoked when object is sent a message it cannot handle.
  #
  # The default implementation will merely raise a NoMethodError with
  # information about the message.
  #
  # This method may be overridden, and is often used to provide dynamic
  # behaviour. An overriding version should call super if it fails to
  # resolve the message. This practice ensures that the default version
  # will called if all else fails.
  #
  def method_missing(meth, *args)
    raise NoMethodError, "Unable to send '#{meth}' on '#{self}' (#{self.class})"
  end

  # :internal:
  #
  # Backend method for Object#dup and Object#clone.
  #
  # Redefined in kernel/common/kernel.rb
  #
  def initialize_copy(other)
  end

  # :internal:
  #
  # Primitive for creating a copy of object.
  #
  # Used by .dup and .clone.
  #
  def copy_object(other)
    Ruby.primitive :object_copy_object
    raise PrimitiveFailure, "Kernel#copy_object primitive failed"
  end

  # :internal:
  #
  # Primitive for properly copying metaclass when copying object.
  #
  # Used by .clone.
  #
  def copy_metaclass(other)
    Ruby.primitive :object_copy_metaclass
    raise PrimitiveFailure, "Kernel#copy_metaclass primitive failed"
  end

  # Generic shallow copy of object.
  #
  # Copies instance variables, but does not recursively copy the
  # objects they reference. Copies taintedness.
  #
  # In contrast to .clone, .dup can be considered as creating a
  # new object of the same class and populating it with data from
  # the object.
  #
  # If class-specific behaviour is desired, the class should
  # define #initialize_copy and implement the behaviour there.
  # #initialize_copy will automatically be called on the new
  # object - the copy - with the original object as argument
  # if defined.
  #
  def dup
    copy = self.class.allocate
    copy.copy_object self
    copy.send :initialize_copy, self
    copy
  end

  # Direct shallow copy of object.
  #
  # Copies instance variables, but does not recursively copy the
  # objects they reference. Copies taintedness and frozenness.
  #
  # In contrast to .dup, .clone can be considered to actually
  # clone the existing object, including its internal state
  # and any singleton methods.
  #
  # If class-specific behaviour is desired, the class should
  # define #initialize_copy and implement the behaviour there.
  # #initialize_copy will automatically be called on the new
  # object - the copy - with the original object as argument
  # if defined.
  #
  def clone
    copy = dup
    copy.copy_metaclass self
    copy.freeze if frozen?
    copy
  end
end


# Module for internals.
#
# See kernel/bootstrap/rubinius.rb
#
module Rubinius

  # Executable abstraction for accessors.
  #
  class AccessVariable

    # Specialised allocation.
    #
    def self.allocate
      Ruby.primitive :accessvariable_allocate
      raise PrimitiveFailure, "AccessVariable.allocate primitive failed"
    end

    # Set up the executable.
    #
    # Name of variable provided without leading @, the
    # second parameter should be true if the attr is
    # writable.
    #
    def initialize(variable, write)
      @primitive = nil
      @serial = 0
      @name = "@#{variable}".to_sym
      @write = write
    end

    # Create a getter for named instance var, without leading @.
    #
    def self.get_ivar(name)
      new(name, false)
    end

    # Create a setter for named instance var, without leading @.
    #
    def self.set_ivar(name)
      new(name, true)
    end
  end

  # Simplified lookup table.
  #
  # See kernel/bootstrap/lookuptable.rb.
  #
  class LookupTable

    # Retrieve value for given key.
    #
    def [](key)
      Ruby.primitive :lookuptable_aref
      raise PrimitiveFailure, "LookupTable#[] primitive failed"
    end

    # Store value under key.
    #
    def []=(key, val)
      Ruby.primitive :lookuptable_store
      raise PrimitiveFailure, "LookupTable#[]= primitive failed"
    end
  end

  # Lookup table for storing methods.
  #
  # See kernel/bootstrap/methodtable.rb and
  #     kernel/common/method_table.rb
  #
  class MethodTable

    # Perform lookup for method name.
    #
    def lookup(name)
      Ruby.primitive :methodtable_lookup
      raise PrimitiveFailure, "MethodTable#lookup primitive failed"
    end

    # Store Executable under name, with given visibility.
    #
    def store(name, exec, visibility)
      Ruby.primitive :methodtable_store
      raise PrimitiveFailure, "MethodTable#store primitive failed"
    end
  end
end


class Symbol
  # Produce String representation of this Symbol.
  #
  def to_s
    Ruby.primitive :symbol_to_s
    raise PrimitiveFailure, "Symbol#to_s primitive failed."
  end

  # For completeness, returns self.
  #
  def to_sym
    self
  end
end


class String
  # Returns the <code>Symbol</code> corresponding to <i>self</i>, creating the
  # symbol if it did not previously exist. See <code>Symbol#id2name</code>.
  #
  #   "Koala".intern         #=> :Koala
  #   s = 'cat'.to_sym       #=> :cat
  #   s == :cat              #=> true
  #   s = '@cat'.to_sym      #=> :@cat
  #   s == :@cat             #=> true
  #
  # This can also be used to create symbols that cannot be represented using the
  # <code>:xxx</code> notation.
  #
  #   'cat and dog'.to_sym   #=> :"cat and dog"
  #--
  # TODO: Add taintedness-check
  #++
  def to_sym
    Ruby.primitive :symbol_lookup
    raise PrimitiveFailure, "Unable to symbolize: #{self.dump}"
  end

  # For completeness, returns self.
  #
  def to_s
    self
  end
end


class Process
  # Terminate with given status code.
  #
  def self.exit(code)
    Ruby.primitive :vm_exit
    raise PrimitiveFailure, "exit() failed. Wow, something is screwed."
  end
end


class Module
  def method_table   ; @method_table ; end
  def constant_table ; @constants    ; end
  def encloser       ; @encloser     ; end
  def name           ; @module_name.to_s    ; end

  # Specialised allocator.
  #
  def self.allocate
    Ruby.primitive :module_allocate
    raise PrimitiveFailure, "Module.allocate primitive failed"
  end

  # :internal:
  #
  # Hook called when a constant cannot be located.
  #
  # Default implementation 'raises', but we don't use #raise
  # to prevent infinite recursion.
  #
  # Redefined in kernel/common/module.rb
  #
  def const_missing(name)
    Rubinius::VM.write_error "Missing or uninitialized constant: \n"
    Rubinius::VM.write_error name.to_s
    Rubinius::VM.write_error "\n"
  end

  # Set Module's direct superclass.
  #
  # The corresponding 'getter' #superclass method defined
  # in class.rb, because it is more complex than a mere
  # accessor
  #
  def superclass=(other)
    @superclass = other
  end

  # Module's stored superclass.
  #
  # This may be either an included Module or an inherited Class.
  #
  def direct_superclass
    @superclass
  end

  # :internal:
  #
  # Perform actual work for including a Module in this one.
  #
  # Redefined in kernel/delta/module.rb.
  #
  def append_features(mod)
    im = Rubinius::IncludedModule.new(self)
    im.attach_to mod
  end

  # Hook method called on Module when another Module is .include'd into it.
  #
  # Override for module-specific behaviour.
  #
  def included(mod); end

  # :internal:
  #
  # Basic version of .include used in kernel code.
  #
  # Redefined in kernel/common/module.rb.
  #
  def include(mod)
    mod.append_features(self)
    mod.__send__ :included, self
    self
  end

  # :internal:
  #
  # Basic version used in kernel code.
  #
  # Redefined in kernel/common/module.rb.
  #
  def attr_reader(name)
    meth = Rubinius::AccessVariable.get_ivar name
    @method_table.store name, meth, :public
    Rubinius::VM.reset_method_cache name
    return nil
  end

  # :internal:
  #
  # Basic version used in kernel code.
  #
  # Redefined in kernel/common/module.rb.
  #
  def attr_writer(name)
    meth = Rubinius::AccessVariable.set_ivar name
    @method_table.store "#{name}=".to_sym, meth, :public
    Rubinius::VM.reset_method_cache name
    return nil
  end

  # :internal:
  #
  # Basic version used in kernel code.
  #
  # Redefined in kernel/common/module.rb.
  #
  def attr_accessor(name)
    attr_reader(name)
    attr_writer(name)
    return true
  end

  # :internal:
  #
  # Basic version used in kernel code.
  # Cannot be used as a toggle, and only
  # takes a single method name.
  #
  # Redefined in kernel/common/module.rb.
  #
  def private(name)
    if entry = @method_table.lookup(name)
      entry.visibility = :private
    end
  end

  # :internal:
  #
  # Basic version used in kernel code.
  # Cannot be used as a toggle, and only
  # takes a single method name.
  #
  # Redefined in kernel/common/module.rb.
  #
  def protected(name)
    if entry = @method_table.lookup(name)
      entry.visibility = :protected
    end
  end

  # :internal:
  #
  # Basic version used in kernel code. Creates a copy
  # of current method and stores it under the new name.
  # The two are independent.
  #
  # Redefined in kernel/common/module.rb.
  #
  def alias_method(new_name, current_name)
    unless entry = @method_table.lookup(current_name)
      mod = direct_superclass()
      while !entry and mod
        entry = mod.method_table.lookup(current_name)
        mod = mod.direct_superclass
      end
    end

    unless entry
      raise NoMethodError, "No method '#{current_name}' to alias to '#{new_name}'"
    end

    @method_table.store new_name, entry.method, entry.visibility
    Rubinius::VM.reset_method_cache(new_name)
  end

  # :internal:
  #
  # Basic version used in kernel code. Only
  # takes a single method name.
  #
  # Redefined in kernel/common/module.rb.
  #
  def module_function(name)
    if entry = @method_table.lookup(name)
      meta = class << self; self; end
      meta.method_table.store name, entry.method, :public
      private name
    end
  end
end


module Rubinius

  # Visibility handling for MethodTables.
  #
  # See kernel/bootstrap/methodtable.rb and
  #     kernel/common/method_table.rb
  #
  class MethodTable::Bucket
    attr_accessor :visibility
    attr_accessor :method

    def public?
      @visibility == :public
    end

    def private?
      @visibility == :private
    end

    def protected?
      @visibility == :protected
    end
  end

  # :internal:
  #
  # Internal representation of a Module's inclusion in another.
  #
  # Abstracts the injection of the included Module into the
  # ancestor hierarchy for method- and constant lookup in a
  # roughly transparent fashion.
  #
  class IncludedModule < Module
    attr_reader :superclass
    attr_reader :module

    # :internal:
    #
    # Specialised allocator.
    #
    def self.allocate
      Ruby.primitive :included_module_allocate
      raise PrimitiveFailure, "IncludedModule.allocate primitive failed"
    end

    # :internal:
    #
    # Created referencing the Module that is being included.
    #
    def initialize(mod)
      @method_table = mod.method_table
      @method_cache = nil
      @name = nil
      @constants = mod.constant_table
      @encloser = mod.encloser
      @module = mod
    end

    # :internal:
    #
    # Inject self inbetween class and its previous direct
    # superclass.
    #
    def attach_to(cls)
      @superclass = cls.direct_superclass
      cls.superclass = self
    end

    # :internal:
    #
    # Name of the included Module.
    #
    def name
      @module.name
    end

    # :internal:
    #
    # String representation of the included Module.
    #
    def to_s
      @module.to_s
    end
  end
end

module Kernel
  alias_method :__class__, :class
end

class Object
  include Kernel

  # :internal:
  #
  # Crude check for whether object can have a metaclass,
  # raises if not.
  #
  # TODO - Improve this check for metaclass support
  def __verify_metaclass__
    if self.__kind_of__(Fixnum) or self.__kind_of__(Symbol)
      raise TypeError, "no virtual class for #{self.class}"
    end
  end
end
