module Goliath
  # The main execution class for Goliath. This will execute in the at_exit
  # handler to run the server.
  #
  # @private
  class Application
    # Most of this stuff is straight out of sinatra.

    # Set of caller regex's to be skipped when looking for our API file
    CALLERS_TO_IGNORE = [ # :nodoc:
      /\/goliath(\/(application))?\.rb$/, # all goliath code
      /rubygems\/custom_require\.rb$/,    # rubygems require hacks
      /bundler(\/runtime)?\.rb/,          # bundler require hacks
      /<internal:/                        # internal in ruby >= 1.9.2
    ]

    # @todo add rubinius (and hopefully other VM impls) ignore patterns ...
    CALLERS_TO_IGNORE.concat(RUBY_IGNORE_CALLERS) if defined?(RUBY_IGNORE_CALLERS)

    # Like Kernel#caller but excluding certain magic entries and without
    # line / method information; the resulting array contains filenames only.
    def self.caller_files
      caller_locations.map { |file, line| file }
    end

    # Like caller_files, but containing Arrays rather than strings with the
    # first element being the file, and the second being the line.
    def self.caller_locations
      caller(1).
        map    { |line| line.split(/:(?=\d|in )/)[0,2] }.
        reject { |file, line| CALLERS_TO_IGNORE.any? { |pattern| file =~ pattern } }
    end

    # Find the app_file that was used to execute the application
    #
    # @return [String] The app file
    def self.app_file
      c = caller_files.first
      c = $0 if !c || c.empty?
      c
    end

    def self.root_path *args
      @root_path ||= File.expand_path(File.dirname(app_file))
      File.join(@root_path, *args)
    end

    # Execute the application
    #
    # @return [Nil]
    def self.run!
      file = File.basename(app_file, '.rb')
      klass = begin
        Kernel.const_get(camel_case(file))
      rescue NameError
        raise NameError, "Class #{camel_case(file)} not found."
      end
      api = klass.new

      runner = Goliath::Runner.new(ARGV, api)
      runner.load_app do
        klass.middlewares.each do |mw|
          use(*(mw[0..1].compact), &mw[2])
        end

        # If you use map you can't use run as
        # the rack builder will blowup.
        if klass.maps.empty?
          run api
        else
          klass.maps.each do |mp|
            map(mp.first, &mp.last)
          end
        end
      end

      runner.load_plugins(klass.plugins)
      runner.run
    end

    private

    # Convert a string to camel case
    #
    # @param str [String] The string to convert
    # @return [String] The camel cased string
    def self.camel_case(str)
      return str if str !~ /_/ && str =~ /[A-Z]+.*/

      str.split('_').map { |e| e.capitalize }.join
    end
  end

  at_exit do
    if $!.nil? && $0 == Goliath::Application.app_file
      Application.run!
    end
  end
end
