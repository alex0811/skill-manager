#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CLI="$ROOT/skill-manager"

assert_eq() {
  local expected=$1
  local actual=$2

  if [[ "$actual" != "$expected" ]]; then
    printf 'Expected:\n%s\nActual:\n%s\n' "$expected" "$actual" >&2
    exit 1
  fi
}

assert_exists() {
  [[ -e "$1" ]] || { printf 'Expected %s to exist\n' "$1" >&2; exit 1; }
}

assert_not_exists() {
  [[ ! -e "$1" ]] || { printf 'Expected %s to not exist\n' "$1" >&2; exit 1; }
}

run_select_with_keys() {
  local home_dir=$1
  local keys=$2
  local output_file status
  output_file=$(mktemp)
  set +e
  printf '%b' "$keys" | HOME="$home_dir" script -q /dev/null "$CLI" select >"$output_file" 2>&1
  status=$?
  set -e
  rm -f "$output_file"
  return "$status"
}

capture_select_with_keys() {
  local home_dir=$1
  local keys=$2
  local output_file
  output_file=$(mktemp)
  printf '%b' "$keys" | HOME="$home_dir" script -q /dev/null "$CLI" select >"$output_file" 2>&1
  perl -pe 's/\r//g' "$output_file"
  rm -f "$output_file"
}

test_list_skills() {
  local home_dir
  home_dir=$(mktemp -d)
  mkdir -p "$home_dir/.claude/skills/enabled-a" "$home_dir/.claude/skills/enabled-b"
  mkdir -p "$home_dir/.claude/skills-disabled/disabled-a"
  mkdir -p "$home_dir/linked-skills/enabled-link" "$home_dir/linked-skills/disabled-link"
  ln -s "$home_dir/linked-skills/enabled-link" "$home_dir/.claude/skills/enabled-link"
  ln -s "$home_dir/linked-skills/disabled-link" "$home_dir/.claude/skills-disabled/disabled-link"

  local actual
  actual=$(HOME="$home_dir" "$CLI" list)
  rm -rf "$home_dir"

  assert_eq $'enabled:\n  enabled-a\n  enabled-b\n  enabled-link\ndisabled:\n  disabled-a\n  disabled-link' "$actual"
}

test_enable_skill() {
  local home_dir
  home_dir=$(mktemp -d)
  mkdir -p "$home_dir/.claude/skills-disabled/foo"

  HOME="$home_dir" "$CLI" enable foo >/dev/null

  assert_exists "$home_dir/.claude/skills/foo"
  assert_not_exists "$home_dir/.claude/skills-disabled/foo"
  rm -rf "$home_dir"
}

test_disable_skill() {
  local home_dir
  home_dir=$(mktemp -d)
  mkdir -p "$home_dir/.claude/skills/foo"

  HOME="$home_dir" "$CLI" disable foo >/dev/null

  assert_exists "$home_dir/.claude/skills-disabled/foo"
  assert_not_exists "$home_dir/.claude/skills/foo"
  rm -rf "$home_dir"
}

test_enable_symlink_skill() {
  local home_dir
  home_dir=$(mktemp -d)
  mkdir -p "$home_dir/.claude/skills-disabled" "$home_dir/linked-skills/foo"
  ln -s "$home_dir/linked-skills/foo" "$home_dir/.claude/skills-disabled/foo"

  HOME="$home_dir" "$CLI" enable foo >/dev/null

  assert_exists "$home_dir/.claude/skills/foo"
  assert_not_exists "$home_dir/.claude/skills-disabled/foo"
  rm -rf "$home_dir"
}

test_disable_symlink_skill() {
  local home_dir
  home_dir=$(mktemp -d)
  mkdir -p "$home_dir/.claude/skills" "$home_dir/linked-skills/foo"
  ln -s "$home_dir/linked-skills/foo" "$home_dir/.claude/skills/foo"

  HOME="$home_dir" "$CLI" disable foo >/dev/null

  assert_exists "$home_dir/.claude/skills-disabled/foo"
  assert_not_exists "$home_dir/.claude/skills/foo"
  rm -rf "$home_dir"
}

test_missing_skill_fails() {
  local home_dir
  home_dir=$(mktemp -d)
  mkdir -p "$home_dir/.claude/skills" "$home_dir/.claude/skills-disabled"

  if HOME="$home_dir" "$CLI" enable missing 2>/dev/null; then
    printf 'Expected missing skill enable to fail\n' >&2
    exit 1
  fi

  rm -rf "$home_dir"
}

test_destination_collision_fails() {
  local home_dir
  home_dir=$(mktemp -d)
  mkdir -p "$home_dir/.claude/skills/foo" "$home_dir/.claude/skills-disabled/foo"

  if HOME="$home_dir" "$CLI" enable foo 2>/dev/null; then
    printf 'Expected destination collision to fail\n' >&2
    exit 1
  fi

  assert_exists "$home_dir/.claude/skills/foo"
  assert_exists "$home_dir/.claude/skills-disabled/foo"
  rm -rf "$home_dir"
}

test_select_requires_tty() {
  local home_dir
  home_dir=$(mktemp -d)
  mkdir -p "$home_dir/.claude/skills/foo"

  if HOME="$home_dir" "$CLI" select >/dev/null 2>/dev/null; then
    printf 'Expected select without tty to fail\n' >&2
    exit 1
  fi

  rm -rf "$home_dir"
}

test_select_with_only_disabled_skills() {
  local home_dir
  home_dir=$(mktemp -d)
  mkdir -p "$home_dir/.claude/skills-disabled/disabled-a"

  run_select_with_keys "$home_dir" $'\n'

  assert_exists "$home_dir/.claude/skills-disabled/disabled-a"
  rm -rf "$home_dir"
}

test_select_duplicate_names_fail() {
  local home_dir
  home_dir=$(mktemp -d)
  mkdir -p "$home_dir/.claude/skills/foo" "$home_dir/.claude/skills-disabled/foo"

  if run_select_with_keys "$home_dir" $'\n'; then
    printf 'Expected duplicate names to fail\n' >&2
    exit 1
  fi

  assert_exists "$home_dir/.claude/skills/foo"
  assert_exists "$home_dir/.claude/skills-disabled/foo"
  rm -rf "$home_dir"
}

test_select_render_uses_square_marks() {
  local home_dir actual
  home_dir=$(mktemp -d)
  mkdir -p "$home_dir/.claude/skills/enabled-a" "$home_dir/.claude/skills-disabled/disabled-b"

  actual=$(capture_select_with_keys "$home_dir" $'q')

  [[ "$actual" == *$'\033[38;2;233;118;88m■\033[0m enabled-a'* ]] || { printf 'Expected selected square mark with RGB color\n' >&2; exit 1; }
  [[ "$actual" == *'□ disabled-b'* ]] || { printf 'Expected unselected square mark\n' >&2; exit 1; }
  rm -rf "$home_dir"
}

test_select_enable_and_disable() {
  local home_dir
  home_dir=$(mktemp -d)
  mkdir -p "$home_dir/.claude/skills/enabled-a" "$home_dir/.claude/skills-disabled/disabled-b"

  run_select_with_keys "$home_dir" $' \033[B \n'

  assert_exists "$home_dir/.claude/skills/disabled-b"
  assert_exists "$home_dir/.claude/skills-disabled/enabled-a"
  assert_not_exists "$home_dir/.claude/skills/enabled-a"
  assert_not_exists "$home_dir/.claude/skills-disabled/disabled-b"
  rm -rf "$home_dir"
}

test_select_enter_without_changes() {
  local home_dir
  home_dir=$(mktemp -d)
  mkdir -p "$home_dir/.claude/skills/enabled-a" "$home_dir/.claude/skills-disabled/disabled-b"

  run_select_with_keys "$home_dir" $'\n'

  assert_exists "$home_dir/.claude/skills/enabled-a"
  assert_exists "$home_dir/.claude/skills-disabled/disabled-b"
  rm -rf "$home_dir"
}

test_select_quit_without_changes() {
  local home_dir
  home_dir=$(mktemp -d)
  mkdir -p "$home_dir/.claude/skills/enabled-a" "$home_dir/.claude/skills-disabled/disabled-b"

  run_select_with_keys "$home_dir" $' q'

  assert_exists "$home_dir/.claude/skills/enabled-a"
  assert_exists "$home_dir/.claude/skills-disabled/disabled-b"
  rm -rf "$home_dir"
}

test_list_skills
test_enable_skill
test_disable_skill
test_enable_symlink_skill
test_disable_symlink_skill
test_missing_skill_fails
test_destination_collision_fails
test_select_requires_tty
test_select_with_only_disabled_skills
test_select_duplicate_names_fail
test_select_render_uses_square_marks
test_select_enable_and_disable
test_select_enter_without_changes
test_select_quit_without_changes

printf 'All tests passed\n'
