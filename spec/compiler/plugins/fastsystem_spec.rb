require File.dirname(__FILE__) + '/../../spec_helper'

describe "A Call node using SendInstructionMethod transform" do
  relates "a.__kind_of__ b" do
    compile do |g|
      g.push :self
      g.send :a, 0, true
      g.push :self
      g.send :b, 0, true
      g.send :__kind_of__, 1, false
    end

    compile :fastsystem do |g|
      g.push :self
      g.send :b, 0, true
      g.push :self
      g.send :a, 0, true
      g.kind_of
    end
  end

  relates "a.__instance_of__ b" do
    compile do |g|
      g.push :self
      g.send :a, 0, true
      g.push :self
      g.send :b, 0, true
      g.send :__instance_of__, 1, false
    end

    compile :fastsystem do |g|
      g.push :self
      g.send :b, 0, true
      g.push :self
      g.send :a, 0, true
      g.instance_of
    end
  end

  relates "a.__nil__" do
    compile do |g|
      g.push :self
      g.send :a, 0, true
      g.send :__nil__, 0, false
    end

    compile :fastsystem do |g|
      g.push :self
      g.send :a, 0, true
      g.is_nil
    end
  end
end
