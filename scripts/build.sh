#!/usr/bin/env bash
set -euo pipefail

mode=${1:-public}
case "$mode" in
  public|personal) ;;
  *)
    echo "Usage: $0 [public|personal]" >&2
    exit 2
    ;;
esac

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
workspace="$root/.build/west"
build="$root/.build/firmware/$mode"
shield="$root/boards/shields/p31n"
macros="$shield/p31n-local-macros.dtsi"
output="$root/dist/p31n-$mode.uf2"

dts_flags=
if [[ "$mode" == personal ]]; then
  if [[ ! -s "$macros" ]]; then
    echo 'Personal build requires p31n-local-macros.dtsi.' >&2
    exit 1
  fi
  dts_flags=-DP31N_PERSONAL_BUILD=1
fi

mkdir -p "$workspace/config"
cp "$root/config/west.yml" "$workspace/config/west.yml"
cd "$workspace"
if [[ ! -d .west ]]; then
  west init -l config
fi
west update --narrow

export ZEPHYR_BASE="$workspace/zephyr"
build_command=(
  west build -p always -s "$workspace/zmk/app" -d "$build"
  -b nrfmicro/nrf52840/zmk -S studio-rpc-usb-uart
  --
  "-DZephyr_DIR=$ZEPHYR_BASE/share/zephyr-package/cmake"
  -DSHIELD=p31n
  "-DZMK_EXTRA_MODULES=$root;$root/modules/p31n-telemetry"
  "-DDTS_EXTRA_CPPFLAGS=$dts_flags"
)

if [[ "$mode" == personal && "${GITHUB_ACTIONS:-}" == true ]]; then
  # Compiler diagnostics may contain lines from the private macro file.
  if ! "${build_command[@]}" >/dev/null 2>&1; then
    echo 'Personal firmware compilation failed. Check the public build and the macro definitions.' >&2
    exit 1
  fi
else
  "${build_command[@]}"
fi

kconfig="$build/zephyr/.config"
dt="$build/zephyr/zephyr.dts.pre"
uf2="$build/zephyr/zmk.uf2"
if ! grep -Fxq 'CONFIG_ZMK_STUDIO_TRANSPORT_UART=y' "$kconfig" ||
   ! grep -Fxq 'CONFIG_ZMK_POINTING=y' "$kconfig" || [[ ! -s "$uf2" ]]; then
  echo 'Expected USB Studio transport, pointing support and a UF2.' >&2
  exit 1
fi

telemetry_setting='# CONFIG_P31N_TELEMETRY is not set'
if grep -Fxq 'CONFIG_P31N_TELEMETRY=y' "$shield/p31n.conf"; then
  telemetry_setting='CONFIG_P31N_TELEMETRY=y'
fi
if ! grep -Fxq "$telemetry_setting" "$kconfig"; then
  echo 'Compiled telemetry setting differs from p31n.conf.' >&2
  exit 1
fi

if [[ ! -s "$dt" ]] ||
   { [[ "$mode" == personal ]] && ! grep -Fq 'p31n-local-macros.dtsi"' "$dt"; } ||
   { [[ "$mode" == public ]] && grep -Fq 'p31n-local-macros.dtsi"' "$dt"; }; then
  echo "Unexpected Devicetree macro source for $mode firmware." >&2
  exit 1
fi

mkdir -p "$(dirname "$output")"
cp "$uf2" "$output"
printf '%s\n' "$telemetry_setting" 'Verified USB Studio transport and pointing support.'
printf 'Built %s (%s bytes)\n' "$output" "$(wc -c < "$output" | tr -d '[:space:]')"
