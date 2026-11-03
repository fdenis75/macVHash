class Vhash < Formula
  desc "Compute phash and oshash for video files"
  homepage "https://github.com/fdenis75/vhash"
  url "https://github.com/fdenis75/vhash/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000" # placeholder: run scripts/release.sh
  license "MIT"
  head "https://github.com/fdenis75/vhash.git", branch: "main"

  depends_on xcode: ["26.0", :build]
  depends_on "ffmpeg"
  depends_on :macos

  def install
    system "swift", "build", "--disable-sandbox", "-c", "release"
    bin.install ".build/release/vhash"
    # Default format appends the shell name: `vhash --generate-completion-script zsh`.
    generate_completions_from_executable(bin/"vhash", "--generate-completion-script")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/vhash --version")
    assert_match "USAGE:", shell_output("#{bin}/vhash --help")

    # oshash needs no ffmpeg; a zero-filled 256 KiB file hashes to its size in hex.
    (testpath/"zeros.mp4").write("\0" * 262_144)
    assert_match "0000000000040000", shell_output("#{bin}/vhash --hash oshash --format csv #{testpath}/zeros.mp4")
  end
end
