#!/usr/bin/env bash

#
# Shared implementation for:
#
#   fax-pdf-gray-200dpi.sh
#   fax-pdf-bilevel-g4-200dpi.sh
#
# This file is sourced by the wrapper scripts.
#

RENDER_DPI="${RENDER_DPI:-400}"
OUTPUT_DPI="${OUTPUT_DPI:-200}"

LEVEL_BLACK="${LEVEL_BLACK:-3}"
LEVEL_WHITE="${LEVEL_WHITE:-97}"

VERBOSE="${VERBOSE:-0}"
KEEP_TMP="${KEEP_TMP:-0}"
PROGRESS="${PROGRESS:-1}"

# A4 at 200 dpi.
#
# 297 mm / 25.4 * 200 = 2338.58 -> 2339 px
# 210 mm / 25.4 * 200 = 1653.54 -> 1654 px
#
A4_LONG_PX=2339
A4_SHORT_PX=1654


fax_log() {
    if [[ "$VERBOSE" == "1" ]]; then
        echo "$@"
    fi
}


fax_error() {
    echo "Error: $*" >&2
}


fax_progress() {
    if [[ "$PROGRESS" == "1" ]]; then
        echo "$@"
    fi
}


fax_usage() {
    cat <<EOF
Usage:
  $(basename "$0") [options] input.pdf [output.pdf]

Options:
  -l, --landscape   Split into A4 landscape pages (default)
  -p, --portrait    Split into A4 portrait pages
  -h, --help        Show this help

Environment:
  PROGRESS=0        Hide progress messages
  VERBOSE=1         Show detailed processing information
  KEEP_TMP=1        Keep temporary files
EOF
}


fax_check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        fax_error "required command not found: $1"
        exit 1
    fi
}


fax_cleanup() {
    if [[ -z "${WORKDIR:-}" ]]; then
        return
    fi

    if [[ "$KEEP_TMP" == "1" ]]; then
        echo "Temporary files: $WORKDIR" >&2
    else
        rm -rf "$WORKDIR"
    fi
}


fax_file_size() {
    if stat -f%z "$1" >/dev/null 2>&1; then
        stat -f%z "$1"
    else
        stat -c%s "$1"
    fi
}


fax_crop_tile() {
    local source="$1"
    local y="$2"
    local destination="$3"

    magick "$source" \
        -crop "${PAGE_WIDTH}x${PAGE_HEIGHT}+0+${y}" \
        +repage \
        -background white \
        -gravity North \
        -extent "${PAGE_WIDTH}x${PAGE_HEIGHT}" \
        +repage \
        "$destination"
}


fax_main() {

    # ------------------------------------------------------------
    # Parse arguments
    # ------------------------------------------------------------

    local orientation="landscape"
    local -a positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--landscape)
                orientation="landscape"
                shift
                ;;

            -p|--portrait)
                orientation="portrait"
                shift
                ;;

            -h|--help)
                fax_usage
                exit 0
                ;;

            --)
                shift
                while [[ $# -gt 0 ]]; do
                    positional+=("$1")
                    shift
                done
                ;;

            -*)
                fax_error "unknown option: $1"
                fax_usage >&2
                exit 1
                ;;

            *)
                positional+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#positional[@]} -lt 1 || ${#positional[@]} -gt 2 ]]; then
        fax_usage >&2
        exit 1
    fi

    INPUT="${positional[0]}"

    if [[ ! -f "$INPUT" ]]; then
        fax_error "file not found: $INPUT"
        exit 1
    fi

    # ------------------------------------------------------------
    # Orientation
    # ------------------------------------------------------------

    case "$orientation" in
        landscape)
            PAGE_WIDTH="$A4_LONG_PX"
            PAGE_HEIGHT="$A4_SHORT_PX"
            ORIENTATION_SUFFIX="landscape"
            ;;

        portrait)
            PAGE_WIDTH="$A4_SHORT_PX"
            PAGE_HEIGHT="$A4_LONG_PX"
            ORIENTATION_SUFFIX="portrait"
            ;;

        *)
            fax_error "invalid orientation: $orientation"
            exit 1
            ;;
    esac

    # ------------------------------------------------------------
    # Output path
    # ------------------------------------------------------------

    local base="${INPUT%.*}"

    OUTPUT="${positional[1]:-${base}-${FAX_OUTPUT_TAG}-a4-${ORIENTATION_SUFFIX}.pdf}"

    # ------------------------------------------------------------
    # Dependencies
    # ------------------------------------------------------------

    fax_check_command pdftoppm
    fax_check_command magick
    fax_check_command img2pdf

    # ------------------------------------------------------------
    # Temporary directory
    # ------------------------------------------------------------

    WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/fax-pdf.XXXXXX")"

    trap fax_cleanup EXIT

    # ------------------------------------------------------------
    # 1. Render original PDF at high resolution
    # ------------------------------------------------------------

    fax_progress "[1/4] Rendering PDF at ${RENDER_DPI} dpi..."

    pdftoppm \
        -r "$RENDER_DPI" \
        -gray \
        -png \
        -aa yes \
        -aaVector yes \
        -thinlinemode shape \
        -progress \
        "$INPUT" \
        "$WORKDIR/source" \
        2> >(
            while IFS=' ' read -r current last path; do

                if [[ "$current" =~ ^[0-9]+$ &&
                      "$last" =~ ^[0-9]+$ ]]; then

                    if [[ "$PROGRESS" == "1" ]]; then
                        echo "      Rendering page ${current}/${last}"
                    fi

                    if [[ "$VERBOSE" == "1" && -n "${path:-}" ]]; then
                        echo "        -> $path"
                    fi

                else
                    printf '%s' "${current:-}" >&2

                    if [[ -n "${last:-}" ]]; then
                        printf ' %s' "$last" >&2
                    fi

                    if [[ -n "${path:-}" ]]; then
                        printf ' %s' "$path" >&2
                    fi

                    printf '\n' >&2
                fi
            done
        )

    # ------------------------------------------------------------
    # Find rendered pages
    # ------------------------------------------------------------

    shopt -s nullglob
    local -a source_files=("$WORKDIR"/source-*.png)
    shopt -u nullglob

    if (( ${#source_files[@]} == 0 )); then
        fax_error "no rendered pages found"
        exit 1
    fi

    local source_count="${#source_files[@]}"

    fax_progress \
        "      Rendering complete: ${source_count} source page(s)"

    # ------------------------------------------------------------
    # Build numerically sorted source-page list
    # ------------------------------------------------------------

    local -a sorted_source_files=()

    while IFS=$'\t' read -r sort_key src; do
        [[ -n "$src" ]] || continue
        sorted_source_files+=("$src")
    done < <(
        for src in "${source_files[@]}"; do

            page="${src##*-}"
            page="${page%.png}"

            if [[ "$page" =~ ^[0-9]+$ ]]; then
                printf \
                    '%010d\t%s\n' \
                    "$((10#$page))" \
                    "$src"
            fi

        done | sort -n
    )

    if (( ${#sorted_source_files[@]} == 0 )); then
        fax_error "could not determine source page order"
        exit 1
    fi

    # ------------------------------------------------------------
    # 2. Resize / split every source PDF page
    # ------------------------------------------------------------

    fax_progress \
        "[2/4] Processing pages as A4 ${orientation}..."

    local output_page=0
    local source_index=0

    for src in "${sorted_source_files[@]}"; do

        source_index=$((source_index + 1))

        local source_page
        source_page="${src##*-}"
        source_page="${source_page%.png}"

        fax_progress \
            "      Source page ${source_index}/${source_count}: resizing..."

        fax_log \
            "        Input file: $src"

        local resized="$WORKDIR/resized.png"

        magick "$src" \
            -colorspace Gray \
            -level "${LEVEL_BLACK}%,${LEVEL_WHITE}%" \
            -filter Lanczos \
            -resize "${PAGE_WIDTH}x" \
            -unsharp 0x0.6+0.5+0.02 \
            -depth 8 \
            -strip \
            "$resized"

        local resized_height

        resized_height="$(
            magick identify \
                -format '%h' \
                "$resized"
        )"

        if [[ ! "$resized_height" =~ ^[0-9]+$ ]]; then
            fax_error "could not determine resized image height"
            exit 1
        fi

        local tile_count
        local remainder

        tile_count=$(( (resized_height + PAGE_HEIGHT - 1) / PAGE_HEIGHT ))
        remainder=$(( resized_height % PAGE_HEIGHT ))

        # 最終ページが丸め誤差レベル（1〜2px）しかない場合は捨てる。
        if (( tile_count > 1 && remainder > 0 && remainder <= 2 )); then
            tile_count=$((tile_count - 1))
        fi

        fax_progress \
            "      Source page ${source_index}/${source_count}: ${tile_count} A4 page(s)"

        fax_log \
            "        Resized size: ${PAGE_WIDTH} x ${resized_height} px"

        local tile_index

        for ((tile_index = 0; tile_index < tile_count; tile_index++)); do

            local tile_number=$((tile_index + 1))
            local y=$((tile_index * PAGE_HEIGHT))

            output_page=$((output_page + 1))

            fax_progress \
                "        Tile ${tile_number}/${tile_count} -> output page ${output_page}"

            local tile="$WORKDIR/tile.png"

            fax_crop_tile \
                "$resized" \
                "$y" \
                "$tile"

            local destination

            destination="$(
                printf \
                    '%s/page-%06d.%s' \
                    "$WORKDIR" \
                    "$output_page" \
                    "$FAX_IMAGE_EXTENSION"
            )"

            fax_encode_tile \
                "$tile" \
                "$destination"
        done
    done

    if (( output_page == 0 )); then
        fax_error "no output pages created"
        exit 1
    fi

    fax_progress \
        "      Image processing complete: ${output_page} A4 page(s)"

    # ------------------------------------------------------------
    # Optional service-specific page limit
    # ------------------------------------------------------------

    if [[ -n "${MAX_PAGES:-}" ]] &&
       (( output_page > MAX_PAGES )); then

        fax_error \
            "output has ${output_page} pages; maximum allowed by this preset is ${MAX_PAGES}"

        exit 1
    fi

    # ------------------------------------------------------------
    # 3. Create PDF
    # ------------------------------------------------------------

    fax_progress \
        "[3/4] Creating PDF from ${output_page} page(s)..."

    shopt -s nullglob
    local -a encoded_pages=(
        "$WORKDIR"/page-*."$FAX_IMAGE_EXTENSION"
    )
    shopt -u nullglob

    if (( ${#encoded_pages[@]} == 0 )); then
        fax_error "no encoded pages found"
        exit 1
    fi

    img2pdf \
        "${encoded_pages[@]}" \
        --output "$OUTPUT"

    # ------------------------------------------------------------
    # 4. Validate
    # ------------------------------------------------------------

    fax_progress "[4/4] Validating output..."

    if [[ ! -s "$OUTPUT" ]]; then
        fax_error "output PDF was not created"
        exit 1
    fi

    local size

    size="$(fax_file_size "$OUTPUT")"

    if [[ ! "$size" =~ ^[0-9]+$ ]]; then
        fax_error "could not determine output file size"
        exit 1
    fi

    local size_mib

    size_mib="$(
        awk \
            -v bytes="$size" \
            'BEGIN { printf "%.2f", bytes / 1024 / 1024 }'
    )"

    echo
    echo "Created: $OUTPUT (${size_mib} MiB, ${output_page} pages)"

    if [[ "$VERBOSE" == "1" ]]; then
        echo "  Orientation : A4 ${orientation}"
        echo "  Page size   : ${PAGE_WIDTH} x ${PAGE_HEIGHT} px"
        echo "  Resolution  : ${OUTPUT_DPI} dpi"
        fax_print_mode_info
    fi

    # ------------------------------------------------------------
    # File-size limit
    # ------------------------------------------------------------

    if [[ -n "${MAX_BYTES:-}" ]] &&
       (( size > MAX_BYTES )); then

        echo \
            "Warning: output exceeds configured limit (${size_mib} MiB)." \
            >&2

        if [[ "${SIZE_LIMIT_FATAL:-0}" == "1" ]]; then
            exit 2
        fi
    fi
}