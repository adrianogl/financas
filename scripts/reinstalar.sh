#!/bin/zsh
set -uo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

repo="$(cd "$(dirname "$0")/.." && pwd)"
devices_json="$(mktemp -t financas-devices)"
trap 'rm -f "$devices_json"' EXIT

log() { print -r -- "[$(date '+%Y-%m-%d %H:%M:%S')] $*" }

notify() {
  osascript -e "display notification \"$1\" with title \"Finanças\"" >/dev/null 2>&1 || true
}

cd "$repo" || exit 1

log "gerando projeto"
xcodegen generate --quiet || { log "xcodegen falhou"; notify "Reinstalação falhou no xcodegen"; exit 1; }

xcrun devicectl list devices --json-output "$devices_json" >/dev/null 2>&1
devices=("${(@f)$(python3 -I -c '
import json, sys
for d in json.load(open(sys.argv[1]))["result"]["devices"]:
    if d["hardwareProperties"].get("reality") == "physical" and d["connectionProperties"].get("pairingState") == "paired":
        print(d["hardwareProperties"]["udid"] + "\t" + d["deviceProperties"]["name"])
' "$devices_json")}")

failed=()
for entry in "${devices[@]}"; do
  [[ -z "$entry" ]] && continue
  udid="${entry%%$'\t'*}"
  name="${entry#*$'\t'}"
  derived="$repo/build/reinstalar/$udid"
  app="$derived/Build/Products/Debug-iphoneos/Financas.app"
  log "build para $name ($udid)"
  if ! xcodebuild \
    -project Financas.xcodeproj \
    -scheme Financas \
    -configuration Debug \
    -destination "id=$udid" \
    -derivedDataPath "$derived" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    -quiet \
    build; then
    log "build falhou: $name"
    failed+=("$name")
    continue
  fi
  log "instalando em $name"
  if xcrun devicectl device install app --device "$udid" "$app" >/dev/null 2>&1; then
    log "ok: $name"
  else
    log "falhou: $name"
    failed+=("$name")
  fi
done

if (( ${#failed[@]} > 0 )); then
  notify "Não instalou em: ${(j:, :)failed}"
  exit 1
fi

log "concluído"
