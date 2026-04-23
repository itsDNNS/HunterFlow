#!/usr/bin/env sh
set -eu

RISKY_PATTERN='UnitAura|C_UnitAuras|UnitPower|UnitHealth|C_Spell\.GetSpellCooldown|C_ActionBar\..*Cooldown|UnitCastingInfo|UnitChannelInfo|COMBAT_LOG|C_NamePlate\.GetNamePlates'

is_allowed_file() {
  case "$1" in
    ./Engine.lua) return 0 ;;
    ./SignalRegistry.lua) return 0 ;;
    ./Display.lua) return 0 ;;
    ./SignalProbe.lua) return 0 ;;
    ./State/CDLedger.lua) return 0 ;;
    ./Profiles/BM_DarkRanger.lua) return 0 ;;
    ./Profiles/BM_PackLeader.lua) return 0 ;;
    ./Profiles/MM_Sentinel.lua) return 0 ;;
    ./Profiles/SV_PackLeader.lua) return 0 ;;
    ./Profiles/SV_Sentinel.lua) return 0 ;;
    ./Profiles/Feral_Wildstalker.lua) return 0 ;;
    ./Profiles/Feral_DruidOfTheClaw.lua) return 0 ;;
    *) return 1 ;;
  esac
}

failed=0

find . -name '*.lua' \
  ! -path './.git/*' \
  ! -path './tests/*' \
  ! -path './scripts/*' \
  | while IFS= read -r file; do
      if grep -E "$RISKY_PATTERN" "$file" >/dev/null 2>&1; then
        if ! is_allowed_file "$file"; then
          echo "Unreviewed risky API use in $file" >&2
          grep -nE "$RISKY_PATTERN" "$file" >&2
          failed=1
        fi
      fi
      if [ "$failed" -ne 0 ]; then
        exit "$failed"
      fi
    done
