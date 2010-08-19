module Integrity
  class Checkout
    def initialize(repo, commit, workspace, directory, logger)
      @repo      = repo
      @commit    = commit
      @workspace = workspace
      @directory = directory
      @logger    = logger
    end

    def run
      runner.run! "git clone #{@repo.uri} #{@workspace}" unless File.directory?(@workspace)
      runner.run! "mkdir -p #{base_build_path}" unless File.directory?(base_build_path)
      
      in_workspace do |c|
        c.run! "git fetch origin"
        c.run! "git checkout origin/#{@repo.branch}"
        c.run! "git reset --hard #{sha1}"
        c.run! "git submodule update --init"
      end
      
      runner.run! "rsync -a --link-dest=#{workspace_path}/ #{workspace_path}/ #{build_path}/"
    end

    def metadata
      format = "---%nidentifier: %H%nauthor: %an " \
        "<%ae>%nmessage: >-%n  %s%ncommitted_at: %ci%n"
      result = run_in_workspace!("git show -s --pretty=format:\"#{format}\" #{sha1}")
      dump   = YAML.load(result.output)

      dump.update("committed_at" => Time.parse(dump["committed_at"]))
    end

    def sha1
      @sha1 ||= @commit == "HEAD" ? head : @commit
    end

    def head
      runner.run!("git ls-remote --heads #{@repo.uri} #{@repo.branch}").output.split.first
    end
    
    def workspace_path
      File.expand_path(@workspace)
    end
    
    def build_path
      File.expand_path(@directory)
    end
    
    def base_build_path
      File.expand_path(@directory.parent)
    end
    
    def run_in_build(command)
      in_build { |r| r.run(command) }
    end

    def run_in_build!(command)
      in_build { |r| r.run!(command) }
    end
    
    def in_build(&block)
      in_dir(@directory, &block)
    end
    
    def run_in_workspace(command)
      in_workspace { |r| r.run(command) }
    end

    def run_in_workspace!(command)
      in_workspace { |r| r.run!(command) }
    end
    
    def in_workspace(&block)
      in_dir(@workspace, &block)
    end
    
    def runner
      @runner ||= CommandRunner.new(@logger)
    end
    
    private
      def run_in_dir(dir, command)
        in_dir(dir) { |r| r.run(command) }
      end

      def run_in_dir!(dir, command)
        in_dir(dir) { |r| r.run!(command) }
      end

      def in_dir(dir, &block)
        runner.cd(dir, &block)
      end
  end
end
