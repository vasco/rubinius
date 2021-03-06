require File.dirname(__FILE__) + '/../spec_helper'

describe "An Attrasgn node" do
  relates <<-ruby do
      y = 0
      42.method = y
    ruby

    parse do
      [:block,
       [:lasgn, :y, [:lit, 0]],
       [:attrasgn, [:lit, 42], :method=, [:arglist, [:lvar, :y]]]]
    end

    compile do |g|
      g.push 0
      g.set_local 0
      g.pop
      g.push 42
      g.push_local 0
      g.dup
      g.move_down 2
      g.send :method=, 1, false
      g.pop
    end
  end

  relates "a.m = *[1]" do
    parse do
      [:attrasgn,
       [:call, nil, :a, [:arglist]],
       :m=,
       [:arglist, [:svalue, [:splat, [:array, [:lit, 1]]]]]]
    end

    # attrasgn_splat
  end

  relates "a[*b] = c" do
    parse do
      [:attrasgn,
       [:call, nil, :a, [:arglist]],
       :[]=,
       [:arglist,
        [:splat, [:call, nil, :b, [:arglist]]],
        [:call, nil, :c, [:arglist]]]]
    end

    compile do |g|
      g.push :self
      g.send :a, 0, true
      g.push :self
      g.send :b, 0, true
      g.cast_array
      g.push :self
      g.send :c, 0, true
      g.dup
      g.move_down 3
      g.swap
      g.push :nil
      g.send_with_splat :[]=, 1, false, true
      g.pop
    end
  end

  relates "a[b, *c] = d" do
    parse do
      [:attrasgn,
       [:call, nil, :a, [:arglist]],
       :[]=,
       [:arglist,
        [:array,
         [:call, nil, :b, [:arglist]],
         [:splat, [:call, nil, :c, [:arglist]]]],
        [:call, nil, :d, [:arglist]]]]
    end

    compile do |g|
      g.push :self
      g.send :a, 0, true
      g.push :self
      g.send :b, 0, true
      g.make_array 1
      g.push :self
      g.send :c, 0, true
      g.cast_array
      g.send :+, 1
      g.push :self
      g.send :d, 0, true
      g.dup
      g.move_down 3
      g.send :[]=, 2, false
      g.pop
    end
  end

  relates "a[b, *c] = *d" do
    parse do
      [:attrasgn,
       [:call, nil, :a, [:arglist]],
       :[]=,
       [:arglist,
        [:array,
         [:call, nil, :b, [:arglist]],
         [:splat, [:call, nil, :c, [:arglist]]]],
        [:svalue, [:splat, [:call, nil, :d, [:arglist]]]]]]
    end

    compile do |g|
      g.push :self
      g.send :a, 0, true
      g.push :self
      g.send :b, 0, true
      g.make_array 1
      g.push :self
      g.send :c, 0, true
      g.cast_array
      g.send :+, 1
      g.push :self
      g.send :d, 0, true
      g.cast_array
      g.dup
      g.send :size, 0
      g.push 1
      g.send :>, 1

      bigger = g.new_label
      g.git bigger
      g.push 0
      g.send :at, 1

      bigger.set!
      g.dup
      g.move_down 3
      g.send :[]=, 2, false
      g.pop
    end
  end

  relates "a[b, *c] = d, e" do
    parse do
      [:attrasgn,
       [:call, nil, :a, [:arglist]],
       :[]=,
       [:arglist,
        [:array,
         [:call, nil, :b, [:arglist]],
         [:splat, [:call, nil, :c, [:arglist]]]],
        [:svalue,
         [:array, [:call, nil, :d, [:arglist]], [:call, nil, :e, [:arglist]]]]]]
    end

    compile do |g|
      g.push :self
      g.send :a, 0, true
      g.push :self
      g.send :b, 0, true
      g.make_array 1
      g.push :self
      g.send :c, 0, true
      g.cast_array
      g.send :+, 1
      g.push :self
      g.send :d, 0, true
      g.push :self
      g.send :e, 0, true
      g.make_array 2
      g.dup
      g.move_down 3
      g.send :[]=, 2, false
      g.pop
    end
  end

  relates "a[42] = 24" do
    parse do
      [:attrasgn,
       [:call, nil, :a, [:arglist]],
       :[]=,
       [:arglist, [:lit, 42], [:lit, 24]]]
    end

    compile do |g|
      g.push :self
      g.send :a, 0, true
      g.push 42
      g.push 24
      g.dup
      g.move_down 3
      g.send :[]=, 2, false
      g.pop
    end
  end

  relates "self[index, 0] = other_string" do
    parse do
      [:attrasgn,
       [:self],
       :[]=,
       [:arglist,
        [:call, nil, :index, [:arglist]],
        [:lit, 0],
        [:call, nil, :other_string, [:arglist]]]]
    end

    compile do |g|
      g.push :self
      g.push :self
      g.send :index, 0, true
      g.push 0
      g.push :self
      g.send :other_string, 0, true
      g.dup
      g.move_down 4
      g.send :[]=, 3, true
      g.pop
    end
  end

  relates <<-ruby do
      a = []
      a [42] = 24
    ruby

    parse do
      [:block,
       [:lasgn, :a, [:array]],
       [:attrasgn, [:lvar, :a], :[]=, [:arglist, [:lit, 42], [:lit, 24]]]]
    end

    compile do |g|
      g.make_array 0
      g.set_local 0
      g.pop
      g.push_local 0
      g.push 42
      g.push 24
      g.dup
      g.move_down 3
      g.send :[]=, 2, false
      g.pop
    end
  end
end
