module Origen
  class OrgFile
    autoload :Interceptor,   'origen/org_file/interceptor'
    autoload :Interceptable, 'origen/org_file/interceptable'

    class << self
      def new(*args, &block)
        if @internal_new
          super
        else
          open(*args, &block)
        end
      end

      def open(id, options = {})
        fail "An org_file is already open with id: #{id}" if open_files[id]
        @internal_new = true
        f = OrgFile.new(id, options)
        @internal_new = nil
        open_files[id] = f
        if block_given?
          yield f
          close(id, options)
        else
          f
        end
      end

      def close(id, options = {})
        fail "An org_file with this ID has not been opened id: #{id}" unless open_files[id]
        open_files[id].close
        open_files[id] = nil
      end

      def org_file(id = nil)
        id ? open_files[id] : open_files.to_a.last[1]
      end

      def cycle(number = 1)
        open_files.each { |id, f| f.cycle(number) }
      end

      private

      def open_files
        @open_files ||= {}.with_indifferent_access
      end
    end

    attr_accessor :path, :filename
    attr_reader :id, :operation

    def initialize(id, options = {})
      @id = id
      @path = options[:path] || default_filepath
      @filename = options[:filename] || "#{id}.org"
      FileUtils.mkdir_p(path)
      @path_to_file = File.join(path, filename)
    end

    def default_filepath
      "#{Origen.root}/pattern/org/#{Origen.target.name}"
    end

    def file
      @file ||= begin
        if operation == 'r'
          fail "No org file found at: #{@path_to_file}" unless exist?
        end
        File.open(@path_to_file, operation)
      end
    end

    def exist?
      File.exist?(@path_to_file)
    end

    def close
      # Corner case, if no call to read_line or record was made then no file was created and there
      # is no file to close
      if @file
        file.puts "#{@buffer}#{@buffer_cycles}" if @buffer
        file.close
      end
    end

    def read_line
      @operation ||= 'r'
      operations = file.readline.strip.split(';')
      cycles = operations.pop.to_i
      operations = operations.map { |op| op.split(',') }.map { |op| op[0] = eval(op[0]); op }
      yield operations, cycles
    end

    def record(path_to_object, method, *args)
      @operation ||= 'w'
      @line ||= ''
      @line += "#{path_to_object},#{method}"
      @line += ",#{args.join(',')}" unless args.empty?
      @line += ';'
    end

    def cycle(number)
      if @buffer
        if @line == @buffer
          @buffer_cycles += 1
        else
          file.puts "#{@buffer}#{@buffer_cycles}"
          @buffer = @line
          @buffer_cycles = 1
        end
      else
        @buffer = @line
        @buffer_cycles = 1
      end
      @line = nil
    end
  end
end
