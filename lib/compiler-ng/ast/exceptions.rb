module Rubinius
  module AST
    class Begin < Node
      attr_accessor :rescue

      def initialize(line, body)
        @line = line
        @rescue = body
      end

      def children
        [@rescue]
      end

      def bytecode(g)
        @rescue.bytecode(g)
      end
    end

    EnsureType = 1

    class Ensure < Node
      attr_accessor :body, :ensure

      def initialize(line, body, ensr)
        @line = line
        @body = body || Nil.new(line)
        @ensure = ensr
      end

      def children
        [@body, @ensure]
      end

      def map_ensure
        @body.in_ensure
        @body.visit do |result, node|
          case node
          when ClosedScope
            result = nil
          else
            node.in_ensure
          end

          result
        end
      end

      def bytecode(g)
        pos(g)
        map_ensure

        ok = g.new_label
        ex = g.new_label
        g.setup_unwind ex, EnsureType

        # TODO: ?
        g.new_label.set!

        @body.bytecode(g)

        g.pop_unwind
        g.goto ok

        ex.set!
        g.push_exception

        @ensure.bytecode(g)
        g.pop

        g.pop_exception

        # Re-raise the exception
        g.reraise

        ok.set!

        # Now, re-emit the code for the ensure which will run if there was no
        # exception generated.
        @ensure.bytecode(g)
        g.pop
      end
    end

    RescueType = 0

    class Rescue < Node
      attr_accessor :body, :rescue, :else

      def initialize(line, body, rescue_body, else_body)
        @line = line
        @body = body
        @rescue = rescue_body
        @else = else_body
      end

      def children
        [@body, @rescue, @else]
      end

      def bytecode(g)
        pos(g)

        g.push_modifiers
        if @body.nil?
          if @else.nil?
            # Stupid. No body and no else.
            g.push :nil
          else
            # Only an else, run it.
            @else.bytecode(g)
          end
        else
          g.retry = g.new_label
          reraise = g.new_label
          els     = g.new_label
          done    = g.new_label

          # Save the current exception into a local
          g.push_exception

          g.retry.set!
          ex = g.new_label
          g.setup_unwind ex, RescueType

          # TODO: ?
          g.new_label.set!

          if current_break = g.break
            # Make a break available to use, which we'll use to
            # lazily generate a cleanup area
            g.break = g.new_label
          end

          @body.bytecode(g)
          g.pop_unwind
          g.goto els

          if current_break
            if g.break.used?
              g.break.set!
              g.pop_unwind

              # Reset the outer exception
              g.swap
              g.pop_exception
              g.goto current_break
            end

            g.break = current_break
          end

          ex.set!
          @rescue.bytecode(g, reraise, done)
          reraise.set!
          g.reraise

          els.set!
          if @else
            g.pop
            @else.bytecode(g)
          end
          done.set!

          g.swap
          g.pop_exception
        end
        g.pop_modifiers
      end
    end

    class RescueCondition < Node
      attr_accessor :conditions, :assignment, :body, :next, :splat

      def initialize(line, conditions, body, nxt)
        @line = line
        @next = nxt

        case conditions
        when ArrayLiteral
          @conditions = conditions
        when ConcatArgs
          @conditions = conditions.array
          @splat = RescueSplat.new line, conditions.rest
        when SplatValue
          @splat = RescueSplat.new line, conditions.value
        when nil
          condition = ConstFind.new line, :StandardError
          @conditions = ArrayLiteral.new line, [condition]
        end

        case body
        when ArrayLiteral
          @assignment = body.shift if assignment? body.first
          @body = body
        when nil
          @body = Nil.new line
        else
          if assignment? body
            @assignment = body
            @body = Nil.new line
          else
            @body = body
          end
        end
      end

      def assignment?(node)
        case node
        when VariableAssignment
          value = node.value
        when AttributeAssignment
          value = node.arguments.array.last
        else
          return false
        end

        return true if value.kind_of? GlobalVariableAccess and value.name == :$!
      end

      def map_rescue
        @body.in_rescue
        @body.visit do |result, node|
          case node
          when ClosedScope
            result = nil
          else
            node.in_rescue
          end

          result
        end
      end

      def children
        [@conditions, @assignment, @body, @next]
      end

      def bytecode(g, reraise, done)
        pos(g)
        body = g.new_label

        if @conditions
          @conditions.body.each do |c|
            c.bytecode(g)
            g.push_exception
            g.send :===, 1
            g.git body
          end
        end

        @splat.bytecode(g, body) if @splat

        if @next
          if_false = g.new_label
          g.goto if_false
        else
          g.goto reraise
        end

        body.set!

        if @assignment
          @assignment.bytecode(g)
          g.pop
        end

        current_break = g.break
        g.break = g.new_label

        map_rescue
        @body.bytecode(g)
        g.clear_exception
        g.goto done

        if g.break.used?
          g.break.set!
          g.clear_exception

          g.swap
          g.pop_exception
          if current_break
            g.goto current_break
          else
            g.raise_break
          end
        end

        g.break = current_break
        if @next
          if_false.set!
          @next.bytecode(g, reraise, done)
        end
      end
    end

    class RescueSplat < Node
      attr_accessor :value

      def initialize(line, value)
        @line = line
        @value = value
      end

      def bytecode(g, body)
        pos(g)

        @value.bytecode(g)
        g.cast_array
        g.push_exception
        g.send :__rescue_match__, 1
        g.git body
      end
    end
  end
end
