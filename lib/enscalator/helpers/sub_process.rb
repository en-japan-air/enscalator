require 'open3'

module Enscalator
  module Helpers
    # Executed command as sub-processes with stdout and stderr streams
    #  taken from: https://nickcharlton.net/posts/ruby-subprocesses-with-stdout-stderr-streams.html
    class SubProcess
      # Create new subprocess and execute command there
      #
      # @param [String] cmd command to be executed
      def initialize(cmd)
        # standard input is not used
        Open3.popen3(cmd) do |_stdin, stdout, stderr, thread|
          { out: stdout, err: stderr }.each do |key, stream|
            Thread.new do
              until (line = stream.gets).nil?
                # yield the block depending on the stream
                if key == :out
                  yield line, nil, thread if block_given?
                else
                  yield nil, line, thread if block_given?
                end
              end
            end
          end
          thread.join # wait for external process to finish
        end
      end
    end

    # Call script
    #
    # @param [String] region AWS region identifier
    # @param [String] dependent_stack_name name of the stack current stack depends on
    # @param [String] script_path path to script
    # @param [Array] keys list of keys
    # @param [String] prepend_args prepend arguments
    # @param [String] append_args append arguments
    # @deprecated this method is no longer used
    def cfn_call_script(region,
                        dependent_stack_name,
                        script_path,
                        keys,
                        prepend_args: '',
                        append_args: '')
      cfn = cfn_resource(cfn_client(region))
      stack = wait_stack(cfn, dependent_stack_name)
      args = get_resources(stack, keys).join(' ')
      cmd = [script_path, prepend_args, args, append_args]
      begin
        run_cmd(cmd)
      rescue Errno::ENOENT
        puts $ERROR_INFO.to_s
        STDERR.puts cmd
      end
    end

    # Run command and print captured output to corresponding standard streams
    #
    # @param [Array] cmd command array to be executed
    # @return [String] produced output from executed command
    def run_cmd(cmd)
      # use contracts to get rid of exceptions: https://github.com/egonSchiele/contracts.ruby
      fail ArgumentError, "Expected Array, but actually was given #{cmd.class}" unless cmd.is_a?(Array)
      fail ArgumentError, 'Argument cannot be empty' if cmd.empty?
      SubProcess.new(cmd.join(' ')) do |stdout, stderr, _thread|
        STDOUT.puts stdout if stdout
        STDERR.puts stderr if stderr
      end
    end
  end
end
