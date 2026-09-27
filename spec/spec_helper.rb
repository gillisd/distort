require "digest"
require "fileutils"
require "securerandom"
require "shellwords"
require "tmpdir"

ENV["PATH"] = [ENV.fetch("PATH", nil), File.expand_path("../build", __dir__)].compact.join(File::PATH_SEPARATOR)
unless ENV["PATH"].split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, "distort")) }
  abort "spec: distort not found on PATH or in build/"
end

RSpec::Matchers.define_negated_matcher :not_match, :match

Dir[File.join(__dir__, "support", "**", "*.rb")].each { |file| require file }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.default_formatter = config.files_to_run.one? ? "doc" : "progress"
  config.order = :random
  Kernel.srand config.seed

  config.before(:example, :dev_full) do
    skip "/dev/full is not available on this platform" unless File.exist?("/dev/full")
  end

  config.before(:example, :terminal) do
    skip "util-linux script is not available on this platform" unless capture("sh", "-c", "script -qec true /dev/null").success?
  end

  config.include Shell
  config.include DistortHelpers
  config.include_context "with a scratch directory"
end
