module Integrity
  class CommandRunner
    class Error < StandardError; end

    Result = Struct.new(:success, :output)

    def initialize(logger)
      @logger = logger
    end

    def cd(dir)
      @dir = dir
      yield self
    ensure
      @dir = nil
    end

    def run(command)
      cmd = normalize(command)

      @logger.debug(cmd)

      output = ""
      IO.popen(cmd, "r") { |io| output = io.read }

      Result.new($?.success?, output.chomp)
    end

    def run!(command)
      result = run(command)

      unless result.success
        @logger.error(result.output.inspect)
        raise Error, "Failed to run '#{command}'"
      end

      result
    end

    def normalize(cmd)
      if @dir
        "(#{pre_bundler_env} && cd #{@dir} && #{cmd} 2>&1)"
      else
        "(#{pre_bundler_env} && #{cmd} 2>&1)"
      end
    end
    
    private
      def pre_bundler_env
        "RUBYOPT=#{pre_bundler_rubyopt} PATH=#{pre_bundler_path}"
      end
      
      def pre_bundler_path
        ENV['PATH'] && ENV["PATH"].split(":").reject { |path| path.include?("bundle") }.join(":")
      end
      
      def pre_bundler_rubyopt
        ENV['RUBYOPT'] && ENV["RUBYOPT"].split.reject { |opt| opt.include?("bundle") }.join(" ")
      end
  end
end
