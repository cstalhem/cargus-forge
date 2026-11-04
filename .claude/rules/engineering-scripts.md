---
paths:
  - "plugins/engineering/**"
---

# Engineering scripts

- A plugin script exists only to work out facts that one pre-approved command cannot give; a single file write is a pre-approved command in `allowed-tools`, never a wrapper script.
- A helper that two plugin scripts need, with the same behaviour in both, lives once in a shared file under the plugin, never copied into each script.
- A script reads each fact once and passes it to every section that needs it.
- A plugin script renders its facts one way for every skill that reads them; a second output exists only for another script, such as status.sh --statuses for labels.sh.
