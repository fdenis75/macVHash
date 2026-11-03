# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0]

### Added
- `vhash` command line tool computing `phash` and `oshash` for video files using the VideoHash library.
- Directory scanning (optionally recursive) with video extension filtering.
- Bounded concurrency (`-j`), table / CSV / JSON output, atomic file output with overwrite protection.
- Single-line stderr progress indicator, `--quiet` and `--verbose`.
- Exit codes 0 / 1 / 2 / 130, graceful SIGINT handling.
- Shell completions (bash, zsh, fish) and a Homebrew formula.
