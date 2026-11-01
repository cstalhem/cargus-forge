#!/usr/bin/env bash
# Tests for the autopilot-t3 skill: its file, the plugin README and the plugin's description.
# They read the repo's files only and need no network.
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
plugin=$(CDPATH= cd -- "$here/../../.." && pwd)
root=$(CDPATH= cd -- "$plugin/../.." && pwd)
skill=$plugin/skills/autopilot-t3/SKILL.md
readme=$plugin/README.md
manifest=$plugin/.claude-plugin/plugin.json
marketplace=$root/.claude-plugin/marketplace.json
root_readme=$root/README.md
failures=0

# expect <description> <command...>: the command must succeed.
expect() {
  local desc=$1
  shift
  if "$@"; then
    echo "ok: $desc"
  else
    echo "FAIL: $desc"
    failures=$((failures + 1))
  fi
}

expect "the skill file exists" test -f "$skill"
if [ ! -f "$skill" ]; then
  echo "1 failed"
  exit 1
fi

# The frontmatter is the text between the first two `---` lines, and the body is the rest.
frontmatter=$(awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } NR > 1' "$skill")
body=$(awk 'NR > 1 && $0 == "---" { seen = 1; next } seen' "$skill")

expect "the frontmatter has name: autopilot-t3" grep -qx 'name: autopilot-t3' <<<"$frontmatter"
expect "the frontmatter has disable-model-invocation: true" \
  grep -qx 'disable-model-invocation: true' <<<"$frontmatter"
expect "the body injects status.sh as the Facts" \
  grep -qF '!`bash "${CLAUDE_PLUGIN_ROOT}/skills/next/status.sh"`' <<<"$body"

# Each T3 tool the skill uses is named in the body.
for tool in orchestrator_capabilities list_scheduled_tasks schedule_task t3_thread_update \
  t3_thread_list t3_thread_read t3_pending_request t3_thread_send t3_thread_launch; do
  expect "the body names the T3 tool $tool" grep -qF "\`$tool\`" <<<"$body"
done

# None of the cloud session's tools, nor its environment variable, is named anywhere in the file.
for name in list_triggers create_trigger update_trigger list_sessions get_session list_events \
  create_session send_message PushNotification CLAUDE_CODE_REMOTE; do
  expect "the skill does not name $name" test "$(grep -cF "$name" "$skill")" = 0
done

expect "the plugin README has an Autopilot on T3 Code section" \
  grep -qx '## Autopilot on T3 Code' "$readme"

# The plugin's description names autopilot-t3 and is identical in the three listings.
description=$(jq -r .description "$manifest")
expect "plugin.json's description names autopilot-t3" grep -qF 'autopilot-t3' <<<"$description"
expect "marketplace.json's description is identical to plugin.json's" \
  test "$(jq -r '.plugins[] | select(.name == "engineering") | .description' "$marketplace")" = "$description"
expect "the root README's plugin index line is identical to plugin.json's description" \
  grep -qxF -- "- **Engineering** (\`plugins/engineering\`): $description" "$root_readme"
expect "the plugin README's first paragraph is plugin.json's description" \
  test "$(sed -n 3p "$readme")" = "$description"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
