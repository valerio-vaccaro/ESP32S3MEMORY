#!/usr/bin/env bash
# Flash a downloaded BitFloppy firmware artifact to an ESP32-S2 board.
# Run from the extracted artifact directory:
#   ./flash_firmware.sh --port /dev/ttyACM0

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./flash_firmware.sh --port PORT [--baud BAUD] [--skip-checksum]

Flash this BitFloppy firmware artifact to a local ESP32-S2 board.

Options:
  --port PORT       Serial port (for example /dev/ttyACM0)
  --baud BAUD       Upload speed (default: 115200)
  --skip-checksum   Do not verify SHA256SUMS.txt before flashing
  -h, --help        Show this help message
EOF
}

port=""
baud="115200"
verify_checksum=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --port)
            [[ $# -ge 2 ]] || { echo "Error: --port requires a value" >&2; exit 2; }
            port="$2"
            shift 2
            ;;
        --baud)
            [[ $# -ge 2 ]] || { echo "Error: --baud requires a value" >&2; exit 2; }
            baud="$2"
            shift 2
            ;;
        --skip-checksum)
            verify_checksum=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[[ -n "$port" ]] || { echo "Error: --port is required" >&2; usage >&2; exit 2; }
[[ "$baud" =~ ^[0-9]+$ ]] || { echo "Error: --baud must be numeric" >&2; exit 2; }

artifact_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
firmware_files=(
    "0x1000_bootloader.bin"
    "0x8000_partitions.bin"
    "0xE000_boot_app0.bin"
    "0x10000_firmware.bin"
)

for firmware_file in "${firmware_files[@]}"; do
    [[ -f "$artifact_dir/$firmware_file" ]] || {
        echo "Error: missing required firmware file: $firmware_file" >&2
        exit 1
    }
done

if "$verify_checksum"; then
    [[ -f "$artifact_dir/SHA256SUMS.txt" ]] || {
        echo "Error: SHA256SUMS.txt is missing (use --skip-checksum to override)" >&2
        exit 1
    }
    (
        cd "$artifact_dir"
        sha256sum --check --strict SHA256SUMS.txt
    )
    echo "Firmware checksums verified."
fi

if ! python3 -m esptool --help >/dev/null 2>&1; then
    echo "Error: esptool is not installed. Install it with: python3 -m pip install esptool" >&2
    exit 1
fi

echo "Flashing BitFloppy firmware. Put the board in bootloader mode if prompted."
exec python3 -m esptool \
    --chip esp32s2 \
    --port "$port" \
    --baud "$baud" \
    write_flash \
    0x1000 "$artifact_dir/0x1000_bootloader.bin" \
    0x8000 "$artifact_dir/0x8000_partitions.bin" \
    0xE000 "$artifact_dir/0xE000_boot_app0.bin" \
    0x10000 "$artifact_dir/0x10000_firmware.bin"
