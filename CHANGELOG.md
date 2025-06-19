# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.4] - 2025-06-1

### Changed
- Added `inline_images` option to enable turning off inlining of images

## [0.0.3] - 2025-04-03

### Changed
- Added `original_quote` to `Jmap.Email`
- `Jmap.Email.text_body` and `Jmap.Email.html_body` are now lists
- Removed some hard-coded references to FastMail, which ignored :provider

## [0.0.2] - 2025-03-31

### Changed
- Lowered Elixir version requirement to ~> 1.12 (from ~> 1.17) to support optional :req dependency
- Made :req an optional dependency
- Relaxed :jason requirement to allow for different JSON parsers
- Introduced HttpClient without :req dependency

## [0.0.1] - 2025-03-28

- Initial release 