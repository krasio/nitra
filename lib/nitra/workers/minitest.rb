module Nitra::Workers
  class Minitest < Worker
    def self.filename_match?(filename)
      filename =~ /_test\.rb/
    end

    def initialize(runner_id, worker_number, configuration)
      super(runner_id, worker_number, configuration)
    end

    def load_environment
      require 'minitest'
      def Minitest.autorun
      end
    end

    def minimal_file
      <<-EOS
      class MinimalTest < Minitest::Test
        def test_minimal
          assert_equal "minitest", "minitest"
        end
      end
      EOS
    end

    def run_file(filename, preloading = false)
      load filename
      exit_code = nil
      output = Nitra::Utils.capture_output do
        exit_code = ::Minitest.run
      end

      output.gsub!(/\e\[\d+m/, '')
      failure = !exit_code

      if failure && @configuration.exceptions_to_retry && @attempt && @attempt < @configuration.max_attempts &&
        output =~ @configuration.exceptions_to_retry
        raise RetryException
      end

      if m = output.match(/(\d+) (runs|tests), \d+ assertions, (\d+) failures, \d+ errors, \d+ skips/)
        test_count = m[1].to_i
        failure_count = m[3].to_i
      else
        test_count = failure_count = 0
      end

      {
        "failure"       => failure,
        "test_count"    => test_count,
        "failure_count" => failure_count,
      }
    end
  end
end
