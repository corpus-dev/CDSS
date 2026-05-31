apply_localization() {
  local PATH_TO_LOCALIZATION="$SCRIPT_DIR/i18n"
  local file_to_include=""
  local lang=""
  local expect_lang=false
  local arg

  for arg in "$@"; do
    if [[ "$expect_lang" == true ]]; then
      lang="$arg"
      break
    fi

    case "$arg" in
      --lang)
        expect_lang=true
        ;;
      --lang=*)
        lang="${arg#--lang=}"
        break
        ;;
    esac
  done

  case "$lang" in
    ""|ua|uk)
      file_to_include=""
      ;;
    en|pl|de|es|it)
      if [[ -f "$PATH_TO_LOCALIZATION/${lang}.sh" ]]; then
        file_to_include="$PATH_TO_LOCALIZATION/${lang}.sh"
      fi
      ;;
    *)
      file_to_include=""
      ;;
  esac

  if [[ "$expect_lang" == true && -z "$lang" ]]; then
    file_to_include=""
  fi

  echo "$file_to_include"
}

if ! declare -p localization >/dev/null 2>&1; then
  declare -A localization=()
fi

trans() {
  if [[ ${#localization[@]} -eq 0 || -z "${localization[$1]:-}" ]]; then
    echo "$1"
  else
    echo "${localization[$1]}"
  fi
}
