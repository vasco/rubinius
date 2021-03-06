TOPLEVEL_BINDING = binding()

module Rubinius
  class Loader
    def initialize
      @exit_code    = 0
      @load_paths   = []
      @requires     = []
      @evals        = []
      @script       = nil
      @verbose_eval = false
      @debugging    = false
      @run_irb      = true
      @printed_version = false
    end

    # Finish setting up after loading kernel.
    def preamble
      @stage = "running Loader preamble"

      Object.const_set :ENV, EnvironmentVariables.new

      String.ruby_parser if ENV['RUBY_PARSER']
      String.sydney_parser if ENV['SYDNEY'] or ENV['SYDPARSE']

      # define a global "start time" to use for process calculation
      $STARTUP_TIME = Time.now

      # set terminal width
      width = 80
      if Terminal and !ENV['RBX_NO_COLS']
        begin
          `which tput &> /dev/null`
          if $?.exitstatus == 0
            width = `tput cols`.to_i
          end
        end
      end
      Rubinius.const_set 'TERMINAL_WIDTH', width

      $VERBOSE = false
    end

    # Setup $LOAD_PATH.
    def system_load_path
      @stage = "setting up system load path"

      # Add a fallback directory if Rubinius::LIB_PATH doesn't exist
      @main_lib = File.expand_path(LIB_PATH)
      @main_lib = File.join(Dir.pwd, 'lib') unless File.exists?(@main_lib)

      # This conforms more closely to MRI. It is necessary to support
      # paths that mkmf adds when compiling and installing native exts.
      additions = []
      additions << SITELIBDIR
      additions << SITEARCHDIR
      additions << SITEDIR
      additions << RUBYLIBDIR
      additions << @main_lib
      additions.uniq!

      $LOAD_PATH.unshift(*additions)

      if ENV['RUBYLIB'] and not ENV['RUBYLIB'].empty? then
        rubylib_paths = ENV['RUBYLIB'].split(':')
        $LOAD_PATH.unshift(*rubylib_paths)
      end
    end

    # Load customization code:
    #   /etc/rbxrc
    #   $HOME/.rbxrc
    #   $RBX_PRELOAD
    def preload
      @stage = "preloading rbxrc code"

      ['/etc/rbxrc',"#{ENV['HOME']}/.rbxrc",ENV['RBX_PRELOAD']].each do |file|
        begin
          load file if file and File.exist?(file)
        rescue LoadError
          nil
        end
      end
    end

    # Register signal handlers.
    def signals
      @stage = "registering signal handlers"

      # Set up a handler for SIGINT that raises Interrupt on the main thread
      Signal.trap("INT") do |sig|
        raise Interrupt, "Thread has been interrupted"
      end
    end

    # Process all command line arguments.
    def options(argv=ARGV)
      @stage = "processing command line arguments"

      options = Options.new "Usage: rbx [options] [--] [script] [arguments]", 25

      options.left_align
      options.on_extra do |x|
        raise Options::ParseError, "Unrecognized option: #{x}" if x[0] == ?-
        if @script.nil? and @evals.empty?
          @script = x
        else
          ARGV.unshift x
        end
        options.stop_parsing
      end

      options.doc "Script is any valid Ruby source file (.rb) or a compiled Ruby file (.rbc)."

      options.doc "\nRuby options"
      options.on "-", "Read and evaluate code from STDIN" do
        @run_irb = false
        $0 = "-"
        Compiler::Utils.execute STDIN.read
      end

      options.on "--", "Stop processing command line arguments" do
        options.stop_parsing
      end

      options.on "-C", "DIR", "Change directory to DIR before running scripts" do |dir|
        @directory = dir
      end

      options.on "-d", "Enable debugging output and set $DEBUG to true" do
        $DEBUG = true
      end

      options.on "-e", "CODE", "Compile and execute CODE" do |code|
        @run_irb = false
        $0 = "(eval)"
        @evals << code
      end

      options.on "-E", "CODE", "Compile and execute CODE (show sexp and bytecode)" do |code|
        @run_irb = false
        $0 = "(eval)"
        @verbose_eval = true
        @evals << code
      end

      options.on "-h", "--help", "Display this help" do
        @run_irb = false
        puts options
        done
      end

      options.on "-i", "EXT", "Edit ARGV files in place, making backup with EXT" do |ext|
        # in place edit mode
        $-i = ext
      end

      options.on "-I", "DIR1[:DIR2]", "Add directories to $LOAD_PATH" do |dir|
        @load_paths << dir
      end

      options.on "-r", "LIBRARY", "Require library before execution" do |file|
        @requires << file
      end

      options.on("-S", "SCRIPT",
                 "Run SCRIPT using PATH environment variable to find it") do |script|
        options.stop_parsing
        @run_irb = false

        search = ENV['PATH'].split(File::PATH_SEPARATOR).unshift(BIN_PATH)
        dir    = search.detect do |d|
          path = File.join(d, script)
          File.exist?(path)
        end

        file = File.join(dir, script) if dir

        $0 = script if file

        # if missing, let it die a natural death
        @script = file ? file : script
      end

      options.on "-v", "Display the version and set $VERBOSE to true" do
        @run_irb = false
        $VERBOSE = true

        unless @printed_version
          puts Rubinius.version
          @printed_version = true
        end
      end

      options.on "-w", "Enable warnings" do
        # TODO: implement
      end

      options.on "--version", "Display the version" do
        @run_irb = false
        puts Rubinius.version
      end

      # TODO: convert all these to -X options
      options.doc "\nRubinius options"
      options.on "--debug", "Launch the debugger" do
        require 'debugger/interface'
        Debugger::CmdLineInterface.new
        @debugging = true
      end

      options.on "--remote-debug", "Run the program under the control of a remote debugger" do
        require 'debugger/debug_server'
        if port = (ARGV.first =~ /^\d+$/ and ARGV.shift)
          $DEBUG_SERVER = Debugger::Server.new(port.to_i)
        else
          $DEBUG_SERVER = Debugger::Server.new
        end
        $DEBUG_SERVER.listen
        @debugging = true
      end

      options.on "--dc", "Display debugging information for the compiler" do
        puts "[Compiler debugging enabled]"
        $DEBUG_COMPILER = true
      end

      options.on "--dl", "Display debugging information for the loader" do
        $DEBUG_LOADING = true
        puts "[Code loading debugging enabled]"
      end

      options.on "--gc-stats", "Show GC stats" do
        stats = Stats::GC.new
        at_exit { stats.show }
      end

      options.on "--melbourne", "Use Melbourne parser and new compiler." do
        require 'compiler-ng'
        Rubinius::CompilerNG.enable
      end

      options.on "--no-rbc", "Don't create .rbc files" do
        @no_rbc = true
      end

      options.on("-P", "[COLUMN]",
                 "Run the profiler, optionally sort output by COLUMN") do |columns|
        require 'profile'
        if columns
          Profiler__.options :sort => columns.split(/,/).map {|x| x.to_sym }
        end
      end

      options.on "--ruby_parser", "Use RubyParser" do
        String.ruby_parser
      end

      options.on "--sydney", "Use SydneyParser" do
        String.sydney_parser
      end

      options.on "--vv", "Display version and extra info" do
        @run_irb = false

        $VERBOSE = true
        puts Rubinius.version
        puts "Options:"
        puts "  Interpreter type: #{INTERPRETER}"
        if jit = JIT
          puts "  JIT enabled: #{jit.join(', ')}"
        else
          puts "  JIT disabled"
        end
        puts
      end

      options.doc <<-DOC
\nVM Options
   -X<variable>[=<value>]
     This option is recognized by the VM before any ruby code loaded.
     It is used to set VM configuration options.

     Use -Xconfig.print to see the list of options the VM recognizes.
     All variables, even ones that VM doesn't understand, are available
     in Rubinius::Config.

     A number of Rubinius features are driven by setting these variables.
      DOC

      options.parse ARGV
    end

    # Update the load paths with any -I arguments.
    def load_paths
      @stage = "setting load paths"

      @load_paths.each do |path|
        path.split(":").reverse_each do |path|
          path = File.expand_path path
          $LOAD_PATH.unshift(path)
        end
      end
    end

    # Require any -r arguments
    def requires
      @stage = "requiring command line files"

      @requires.each { |file| require file }
    end

    # Evaluate any -e arguments
    def evals
      @stage = "evaluating command line code"

      @evals.each do |code|
        eval(code, TOPLEVEL_BINDING) do |compiled_method|
          if @verbose_eval
            p code.to_sexp("(eval)", 1)
            puts compiled_method.decode
          end
        end
      end
    rescue SystemExit => e
      @exit_code = e.status
    end

    # Run all scripts passed on the command line
    def script
      return unless @script and @evals.empty?

      @stage = "running #{@script}"
      Dir.chdir @directory if @directory

      if File.exist?(@script)
        $0 = @script

        # make sure that the binding has a script associated with it
        # and theat the script has a path
        TOPLEVEL_BINDING.static_scope.script = CompiledMethod::Script.new
        TOPLEVEL_BINDING.static_scope.script.path = @script

        Compiler::Utils.debug_script! if @debugging
        Compiler::Utils.load_from_extension @script,
          :no_rbc => @no_rbc, :root_script => true
      else
        if @script.suffix?(".rb")
          puts "Unable to find '#{@script}'"
          exit! 1
        else
          prog = File.join @main_lib, "bin", "#{@script}.rb"
          if File.exist? prog
            $0 = prog
            load prog
          else
            raise LoadError, "Unable to find a script '#{@script}' to run"
          end
        end
      end
    rescue SystemExit => e
      @exit_code = e.status
    end

    # Run IRB unless we were passed -e, -S arguments or a script to run.
    def irb
      return if $0 or not @run_irb

      @stage = "running IRB"

      if Terminal
        repr = ENV['RBX_REPR'] || "bin/irb"
        $0 = repr
        prog = File.join @main_lib, repr
        begin
          # HACK: this was load but load raises LoadError
          # with prog == "lib/bin/irb". However, require works.
          # Investigate when we have specs running.
          require prog
        rescue LoadError => e
          STDERR.puts "Unable to find repr named '#{repr}' to load."
          puts e.awesome_backtrace.show
          exit 1
        end
      else
        $0 = "(eval)"
        Compiler::Utils.execute "p #{STDIN.read}"
      end
    end

    # Cleanup and at_exit processing.
    def epilogue
      @stage = "at_exit handler"
      AtExit.shift.call until AtExit.empty?

      @stage = "object finalizers"
      ObjectSpace.run_finalizers

      # TODO: Fix these with better -X processing
      if Config['rbx.jit_stats']
        p VM.jit_info
      end

      if Config['rbx.gc_stats']
        Stats::GC.new.show
      end
    end

    # Exit.
    def done
      Process.exit @exit_code
    end

    # Orchestrate everything.
    def main
      preamble
      system_load_path
      preload
      signals
      options
      load_paths
      requires
      evals
      script
      irb
      epilogue

    rescue SystemExit => e
      @exit_code = e.status

    rescue SyntaxError => e
      puts "A syntax error has occured:"
      puts "    #{e.message}"
      puts "    near line #{e.file}:#{e.line}, column #{e.column}"
      puts "\nCode:\n#{e.code}"
      if e.column
        puts((" " * (e.column - 1)) + "^")
      end

      puts "\nBacktrace:"
      puts e.awesome_backtrace.show
      @exit_code = 1

    rescue Object => e
      begin
        if e.kind_of? Exception
          msg = e.message
        else
          msg = "strange object detected as exception: #{e.inspect}"
        end

        puts "An exception occurred #{@stage}"
        puts "    #{e.message} (#{e.class})"

        puts "\nBacktrace:"
        puts e.awesome_backtrace.show
        @exit_code = 1

      rescue Object => e2
        puts "\n====================================="
        puts "Exception occurred during top-level exception output! (THIS IS BAD)"
        puts
        puts "Original Exception: #{e.inspect} (#{e.class})"
        puts "New Exception: #{e2.inspect} (#{e.class})"
        @exit_code = 128
      end
    ensure
      done
    end
  end
end

Rubinius::Loader.new.main
