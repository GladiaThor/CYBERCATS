render_cc_header() {
  local template
  template=$(< $HEADER_ART_DIR)
  printf "%b\n" "${(e)template}"
}
