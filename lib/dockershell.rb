require 'json'
require 'open3'

class Dockershell
  def initialize(options)
    @options = options
    @logger  = options[:logger]
    @gempath = File.expand_path('..', File.dirname(__FILE__))

    @options[:name] ||= wordgen
    @options[:fqdn] ||= "#{@options[:name]}.#{@options[:domain]}"
    @options[:profile][:volumes] ||= []

    @logger.formatter = proc do |severity, datetime, progname, msg|
      "#{datetime} #{severity.ljust(5)} [#{@options[:name]}] #{msg}\n"
    end
  end

  def run!
    at_exit do
      detached_postrun
    end
    prerun
    create unless running?
    setup
    start
  end

  def start
    @logger.info 'starting Dockershell.'
	if Gem.win_platform?
		args = 'docker', 'exec', '-it', @options[:name], 'powershell.exe'
	else
		args = 'docker', 'exec', '-it', @options[:name], 'script', '-qc', 'bash', '/dev/null'
	end
    bomb 'could not start container.' unless system(*args)
  end

  def kill(container)
    @logger.info "Killing container: #{container}."

    output, status = Open3.capture2e('docker', 'kill', container)
    @logger.debug output
    @logger.warn 'could not stop container' unless status.success?

    output, status = Open3.capture2e('docker', 'rm', '-f', container)
    @logger.debug output
    @logger.warn 'could not remove container' unless status.success?
  end

  [:prerun, :setup, :postrun].each do |task|
    define_method(task) do
      return unless @options[:profile].include? task
      script = which(@options[:profile][task]) || return
      @logger.debug "#{task}: #{script} #{@options[:fqdn]} #{@options[:option]}"

      # This construct allows us to have an optional 2nd parameter to the script
      output, status = Open3.capture2e(*[script, @options[:fqdn], @options[:option]].compact)
      @logger.debug output
      bomb "#{task} task '#{script} #{@options[:name]} #{@options[:option]}' failed." unless status.success?
    end
  end

  # This spawns a detached process to clean up. This is so it doesn't die when the parent is killed
  def detached_postrun
    @logger.info 'terminating and cleaning up.'

    if Gem.win_platform?
      # windows doesn't have fork, this is as close as we can get
      require 'win32/process'
      command = File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'dockershell'))
      cmdexe = ENV['ComSpec']
      command = "#{ENV['ComSpec']}/cmd.exe /C dockershell --kill #{@options[:name]}"
      cleaner = Process.create(
         :command_line     => "dockershell --kill #{@options[:name]}",
         :creation_flags   => Process::DETACHED_PROCESS,
         :process_inherit  => false,
         :thread_inherit   => false,
         :cwd              => "C:\\",
         :environment      => "SYSTEMROOT=#{ENV['SYSTEMROOT']};PATH=C:\\",
      )
      postrun

    else
      cleaner = Process.fork do
        Process.setsid
        kill(@options[:name])
        postrun
      end
      Process.detach cleaner
    end
  end

private
  def running?
    data = `docker ps -a`.split("\n")
    data.shift # remove column header

    names = data.map { |line| line.split.last }
    if names.include? @options[:name]
      output, status = Open3.capture2e('docker', 'inspect', @options[:name])
      bomb 'could not get container info.' unless status.success?

      info = JSON.parse(output)
      bomb 'multiple containers with this name exist.' unless info.size == 1

      info = info.first
      @logger.debug(info['State'].inspect)

      bomb 'Inconsistent Docker state.' unless info['State']['Running']
      true
    else
      false
    end
  end

  def create
    @logger.info 'creating container.'
    args = [
      'docker', 'run',
      '--hostname', "#{@options[:fqdn]}",
      '--name', @options[:name],
      "--add-host=puppet:#{@options[:docker][:ipaddr]}",
      '--expose=80', '-Ptd',
    ]

    @options[:profile][:volumes].each do |volume|
      args << '--volume' << volume
    end

    if Gem.win_platform?
      args << @options[:profile][:image] << "powershell.exe"
    else
      args << '--security-opt' << 'seccomp=unconfined'
      args << '--stop-signal=SIGRTMIN+3'
      args << '--tmpfs' << '/tmp' << '--tmpfs' << '/run'
      args << '--volume' << '/sys/fs/cgroup:/sys/fs/cgroup:ro'
      args << @options[:profile][:image] << '/sbin/init'
    end

    output, status = Open3.capture2e(*args)
    @logger.debug output
    bomb 'could not create container.' unless status.success?
  end

  def bomb(message)
    @logger.warn message
    raise "[#{@options[:name]}] #{message}"
  end

  def which(name)
    ["/etc/dockershell/scripts/#{name}", "#{@gempath}/scripts/#{name}"].each do |path|
      return path if File.file? path and File.executable? path
    end
    nil
  end

  def wordgen
    words = File.readlines("#{@gempath}/resources/places.txt").each { |l| l.chomp! }

    "#{words.sample}-#{words.sample}"
  end

end
