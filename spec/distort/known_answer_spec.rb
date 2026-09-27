RSpec.describe "distort decrypt of the reference stream" do
  subject(:result) { distort("decrypt", "--key-file=#{fixture('known-answer.key')}", fixture("known-answer.txt.enc")) }

  let(:plaintext) { File.binread(fixture("known-answer.txt")) }

  it "exits with status 0" do
    expect(result.exitstatus).to eq(0)
  end

  it "reproduces the known plaintext exactly" do
    expect(sha256(result.stdout)).to eq(sha256(plaintext))
  end

  it "writes nothing to stderr" do
    expect(result.stderr).to be_empty
  end

  context "when the stream is decrypted with another key" do
    it "exits with status 1" do
      expect(decrypt(File.binread(fixture("known-answer.txt.enc"))).exitstatus).to eq(1)
    end
  end
end
