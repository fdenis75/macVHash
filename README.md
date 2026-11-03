# vhash

Command line tool that computes **phash** (perceptual hash) and **oshash** (OpenSubtitles hash) for video
files, built on [VideoHash](https://github.com/fdenis75/VideoHash).

- Requires macOS 26 and Swift 6.2 (Xcode 26) to build.
- `phash` needs **ffmpeg** (`brew install ffmpeg`). `oshash` does not, and needs files of at least 128 KiB.
  `vhash --hash oshash ...` never touches ffmpeg.

## Install

### Homebrew (tap)

```sh
brew tap <you>/tap          # repository: homebrew-tap
brew install vhash
```

### From source

```sh
swift build -c release
install -m 755 .build/release/vhash /usr/local/bin/vhash
```

## Usage

```sh
vhash movie.mp4                              # both hashes, table on stdout
vhash -r ~/Movies --hash oshash -j 4         # recursive, oshash only, 4 files at a time
vhash ~/Movies -f csv -o hashes.csv          # CSV file (refuses to overwrite without --force)
vhash a.mp4 b.mkv -H phash -H oshash -f json
find . -name '*.mkv' | vhash - -f json       # paths from stdin
vhash -- -odd-name.mp4                       # '--' ends option parsing
```

Inputs are files or directories. Directories are scanned non-recursively unless `-r` is given, and only
files with a video extension (mp4 m4v mov mkv avi wmv flv webm mpg mpeg ts m2ts mts 3gp ogv vob,
case-insensitive) are picked up; hidden files and directories are skipped. Files named explicitly are always
accepted. Paths are de-duplicated and results are sorted by path.

| Option | Meaning |
| --- | --- |
| `-r, --recursive` | Descend into subdirectories |
| `-H, --hash <phash\|oshash\|all>` | Algorithms; repeatable or comma-separated (default `all`) |
| `-j, --concurrency <n>` | Files hashed at once, `>= 1` (default 2) |
| `--ffmpeg-path <path>` | ffmpeg executable (default: search `PATH`, then Homebrew locations) |
| `-f, --format <table\|csv\|json>` | Output format (default `table`; inferred from `-o` extension `.csv`/`.json`, else `table`) |
| `-o, --output <file>` | Write results to a file atomically |
| `--force` | Allow `-o` to overwrite an existing file |
| `-q, --quiet` | No progress or warnings (errors still printed) |
| `-v, --verbose` | One line per file on stderr |
| `-h, --help`, `--version` | |

Stdout carries only results. Progress (a single updating line, only when stderr is a TTY and not `--quiet`),
warnings and errors go to stderr. `NO_COLOR` disables colour; there is no ANSI output when stderr is not a TTY.
Set `VHASH_DEBUG=1` to see the VideoHash library's own logging.

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | All files hashed |
| 1 | Some files failed; results for the rest are still emitted |
| 2 | Usage or fatal error (bad arguments, missing path, no videos, ffmpeg missing for phash, output problems) |
| 130 | Interrupted with Ctrl-C; results gathered so far are emitted |

## Output schemas

**JSON**: array of objects, pretty printed, keys sorted. Hashes that were not requested are `null`;
`error` is `null` on success.

```json
[
  {
    "duration" : 8,
    "error" : null,
    "oshash" : "56a9d74d2bc0dd96",
    "path" : "/Users/me/Movies/a.mp4",
    "phash" : "8a65c38c58e3f33c"
  }
]
```

**CSV**: RFC 4180 quoting, header row `path,phash,oshash,duration,status,error`; `duration` in seconds,
`status` is `ok` or `error`.

**Table**: aligned columns for the requested hashes plus `DURATION` (`h:mm:ss`); an `ERROR` column appears only
when something failed.

## Shell completions

```sh
vhash --generate-completion-script zsh|bash|fish
```

Pre-generated files live in `completions/` (`_vhash`, `vhash.bash`, `vhash.fish`); regenerate them with
`scripts/generate-completions.sh`. The Homebrew formula installs them automatically.

## Releasing and Homebrew

1. Bump `VHashInfo.version` in `Sources/VHashCore/VHashInfo.swift` and `CHANGELOG.md`, commit.
2. `scripts/release.sh 0.1.0` runs the tests, tags `v0.1.0`, pushes the tag and prints the tarball sha256.
3. Create a GitHub repository named `homebrew-tap` (once), with a `Formula/` directory.
4. Put the new `url` and `sha256` in `Formula/vhash.rb`, copy it to `homebrew-tap/Formula/vhash.rb`, commit, push.
5. Users install with `brew tap <you>/tap && brew install vhash` (or `brew install <you>/tap/vhash`).

Check the formula locally with `brew style Formula/vhash.rb` and `brew install --build-from-source ./Formula/vhash.rb`.
The formula uses `generate_completions_from_executable(bin/"vhash", "--generate-completion-script")`, which
runs `vhash --generate-completion-script <shell>` for bash, zsh and fish.

## Development

```sh
swift build
swift test            # Swift Testing; uses a fake hasher, no ffmpeg or videos needed
```

Layout: `Sources/VHashCore` (scanner, runner, formatters, command) and `Sources/vhash` (thin `main.swift`).
Inject a `HashProviding` to test without real videos.

## Known limitations

- phash relies on AVFoundation to open the file, so containers AVFoundation cannot read (for example many
  `.mkv` files) fail with `Cannot Open`; their `oshash` still works with `--hash oshash`.
- If one requested hash fails for a file, the whole file is reported as failed.
- A man page is not shipped.

## License

MIT, see `LICENSE`.
