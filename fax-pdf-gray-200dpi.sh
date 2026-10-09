#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")" &&
    pwd
)"

#
# Gray / JPEG preset
#

FAX_OUTPUT_TAG="fax-gray-200dpi"
FAX_IMAGE_EXTENSION="jpg"

JPEG_QUALITY=85

# MOVFAX: 10 MiB preset limit
MAX_BYTES=$((10 * 1024 * 1024))

# Warn only.
SIZE_LIMIT_FATAL=0


fax_encode_tile() {
    local source="$1"
    local destination="$2"

    magick "$source" \
        -colorspace Gray \
        -depth 8 \
        -strip \
        -units PixelsPerInch \
        -density "$OUTPUT_DPI" \
        -quality "$JPEG_QUALITY" \
        "$destination"
}


fax_print_mode_info() {
    echo "  Color       : 8-bit grayscale"
    echo "  Compression : JPEG quality ${JPEG_QUALITY}"
}


source "$SCRIPT_DIR/fax-pdf-common.sh"

fax_main "$@"