module IRB
  class IrbRubinius < Irb
    def process_statements
      @scanner.each_top_level_statement do |line, line_no|
        signal_status(:IN_EVAL) do
          begin
            line.untaint
            @context.evaluate(line, line_no)
            output_value if @context.echo?
          rescue SystemExit, Rubinius::ThrownValue => e
            $! = e
          rescue Object => e

            puts "#{e.class}: #{e.message}"

            bt = e.awesome_backtrace

            continue = true
            bt.each do |frame|
              next unless continue
              recv = frame.describe
              loc = frame.position
              if %r!kernel/common/eval.rb!.match(loc)
                continue = false
                next
              end

              if %r!main.irb_binding!.match(recv)
                puts "   from #{recv}"
                break
              end

              puts "   from #{recv} at #{loc}"
            end
          end
        end
      end
    end
  end
end

IRB.conf[:IRB_CLASS] = IRB::IrbRubinius
