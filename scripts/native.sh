#!/usr/bin/env bash
set -euo pipefail

# Keep machine-specific toolchain fixes inside this process, never in shell files.
if [[ "$(uname)" == Darwin ]]; then
  if [[ -z "${ANDROID_HOME:-}" && -d "$HOME/Library/Android/sdk" ]]; then
    export ANDROID_HOME="$HOME/Library/Android/sdk"
  fi
  if [[ "${2:-}" == ios ]] && command -v brew >/dev/null 2>&1; then
    # Inspect installed opt links without asking Homebrew to refresh its API.
    tinta_prefix="$(cd "$(dirname "$(command -v brew)")/.." && pwd -P)"
    tinta_ruby="$tinta_prefix/opt/ruby"
    tinta_pods="$tinta_prefix/opt/cocoapods"
    if [[ -x "$tinta_ruby/bin/ruby" && -d "$tinta_pods/libexec" ]]; then
      # Homebrew CocoaPods must use the gems from its current Ruby, not an older
      # Ruby directory left in GEM_PATH after a Homebrew upgrade.
      tinta_gems="$("$tinta_ruby/bin/ruby" -rrubygems -e 'print Gem.default_dir')"
      tinta_ruby_api="$("$tinta_ruby/bin/ruby" -rrbconfig -e 'print RbConfig::CONFIG["ruby_version"]')"
      export GEM_PATH="$tinta_pods/libexec:$tinta_ruby/lib/ruby/gems/$tinta_ruby_api:$tinta_gems"
    fi
  fi
fi

exec ns "$@"
