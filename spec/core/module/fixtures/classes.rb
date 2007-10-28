module ModuleSpecs
  class Parent
    # For private_class_method spec
    def Parent.private_method; end
    failure :rubinius do
      private_class_method :private_method
    end

    # For public_class_method spec
    private
    def Parent.public_method; end
    failure :rubinius do
      public_class_method :public_method
    end

    public
    def public_parent() end
    protected
      def protected_parent() end
    private
      def private_parent() end
  end
    
  module Basic
    def public_module() end
    protected
      def protected_module() end
    private
      def private_module() end
  end
  
  module Super
    include Basic
    
    def public_super_module() end
    protected
      def protected_super_module() end
    private
      def private_super_module() end
        
    class SuperChild
    end
  end
    
  module Internal
  end

  class Child < Parent
    include Super

    class << self
      include Internal
    end
    
    def public_child() end
    protected
      def protected_child() end
    private
      def private_child() end
  end

  # Be careful touching the Counts* classes as there used for testing
  # private_instance_methods, public_instance_methods, etc.  So adding, removing
  # a method will break those tests.
  module CountsMixin
    def public_3; end
    private
    def private_3; end
    protected
    def protected_3; end
  end

  class CountsParent
    include CountsMixin

    def public_2; end
    private
    def private_2; end
    protected
    def protected_2; end
  end
 
  class CountsChild < CountsParent
    def public_1; end
    private
    def private_1; end
    protected
    def protected_1; end
  end

  module A
    CONSTANT_A = :a
    OVERRIDE = :a
    def ma(); :a; end
    def self.cma(); :a; end
  end
  module B
    CONSTANT_B = :b
    OVERRIDE = :b
    include A
    def mb(); :b; end
    def self.cmb(); :b; end
  end
  class C
    OVERRIDE = :c
    include B    
  end
end
  
