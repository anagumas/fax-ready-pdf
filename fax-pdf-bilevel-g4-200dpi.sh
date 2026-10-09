#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")" &&
    pwd
)"

#
# Bilevel / CCITT Group 4 preset
#

FAX_OUTPUT_TAG="fax-bilevel-g4-200dpi"
FAX_IMAGE_EXTENSION="tif"

THRESHOLD=55

# 秒速FAX preset
MAX_BYTES=$((1 * 1024 * 1024))
MAX_PAGES=10

# Treat exceeding 1 MiB as failure.
SIZE_LIMIT_FATAL=1


fax_encode_tile() {
    local source="$1"
    local destination="$2"

    magick "$source" \
        -colorspace Gray \
        -threshold "${THRESHOLD}%" \
        -type Bilevel \
        -depth 1 \
        -strip \
        -units PixelsPerInch \
        -density "$OUTPUT_DPI" \
        -compress Group4 \
        "$destination"
}


fax_print_mode_info() {
    echo "  Color       : 1-bit bilevel"
    echo "  Threshold   : ${THRESHOLD}%"
    echo "  Compression : CCITT Group 4"
}


source "$SCRIPT_DIR/fax-pdf-common.sh"

fax_main "$@"