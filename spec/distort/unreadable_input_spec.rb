RSpec.describe "distort with unreadable input" do
  %w[encrypt decrypt].each do |command|
    describe command do
      {
        "a directory named as FILE" => ->(dir) { { args: [dir], stdin_from: nil, name: dir } },
        "a directory on stdin" => ->(dir) { { args: [], stdin_from: dir, name: "(standard input)" } },
        "a directory on stdin named as -" => ->(dir) { { args: ["-"], stdin_from: dir, name: "(standard input)" } }
      }.each do |description, source|
        context "when given #{description}" do
          subject(:outcome) do
            bounded("distort", command, "--key-file=#{key_path}", *input[:args], stdin_from: input[:stdin_from])
          end

          let(:input) { source.call(workdir) }

          it "exits within five seconds" do
            expect(outcome).to be_finished
          end

          it "exits with status 1" do
            expect(outcome.exitstatus).to eq(1)
          end

          it "writes nothing to stdout" do
            expect(outcome.stdout).to be_empty
          end

          it "names the input and the reason on stderr" do
            expect(outcome.stderr).to eq("distort: #{input[:name]}: Is a directory\n")
          end
        end
      end
    end
  end
end
