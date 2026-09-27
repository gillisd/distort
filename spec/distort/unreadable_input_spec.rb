RSpec.describe "distort with unreadable input" do
  %w[encrypt decrypt].each do |command|
    describe command do
      {
        "a directory named as FILE" => ->(dir) { { args: [dir], stdin_from: nil } },
        "a directory on stdin" => ->(dir) { { args: [], stdin_from: dir } }
      }.each do |description, source|
        context "when given #{description}" do
          subject(:outcome) do
            input = source.call(workdir)
            bounded("distort", command, "--key-file=#{key_path}", *input[:args], stdin_from: input[:stdin_from])
          end

          it "exits within five seconds" do
            expect(outcome).to be_finished
          end

          it "fails" do
            expect(outcome).not_to be_success
          end

          it "writes nothing to stdout" do
            expect(outcome.stdout).to be_empty
          end

          it "explains the problem on stderr" do
            expect(outcome.stderr).not_to be_empty
          end
        end
      end
    end
  end
end
