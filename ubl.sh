
#Colors ────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD="\033[1m"
  DIM="\033[2m"
  GREEN="\033[32m"
  RED="\033[31m"
  CYAN="\033[36m"
  RESET="\033[0m"
else
  BOLD="" DIM="" GREEN="" RED="" CYAN="" RESET=""
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { printf '%b\n' " ${CYAN}[..]${RESET} ${DIM}$*${RESET}"; }
ok()      { printf '%b\n' " ${GREEN}[OK]${RESET} $*"; }
die() {
  {
    printf "\033[?25h" # Restore cursor
    if [[ $# -gt 0 ]]; then
      printf '\n%b\n' " ${RED}[ERR]${RESET} $*"
    else
      printf '\n%b\n' " ${RED}[ERR]${RESET} Installation failed or was cancelled."
    fi
    printf "For manual patching and installation:\n"
    printf "%bhttps://gist.github.com/Brajesh2022/e42160d29b55417db6c18c52dd1d6d37%b\n\n" "$CYAN" "$RESET"
  } >&2
  exit 1
}
divider() { printf '%b\n' "${DIM}────────────────────────────────────────${RESET}"; }

terminal_cols() {
  local cols
  if [[ -t 1 ]] && cols=$(tput cols 2>/dev/null) && [[ "$cols" =~ ^[0-9]+$ ]] && (( cols > 0 )); then
    echo "$cols"
    return
  fi
  echo 60
}

spinner() {
  local pid=$1
  local msg=$2
  local spinstr='\|/-'
  printf "\033[?25l" # Hide cursor
  while kill -0 "$pid" 2>/dev/null; do
    local temp=${spinstr#?}
    printf "\r\033[K %b[%c]%b %b%s%b" "$CYAN" "$spinstr" "$RESET" "$DIM" "$msg" "$RESET"
    local spinstr=$temp${spinstr%"$temp"}
    sleep 0.1
  done
  local exit_status=0
  wait "$pid" || exit_status=$?
  if [ $exit_status -eq 0 ]; then
    printf "\r\033[K %b[OK]%b %s\n" "$GREEN" "$RESET" "$msg"
  else
    printf "\r\033[K %b[ERR]%b %s\n" "$RED" "$RESET" "$msg"
  fi
  printf "\033[?25h" # Show cursor
  return $exit_status
}

download_with_progress() {
  local url=$1
  local dest=$2

  printf "\033[?25l" # Hide cursor

  local total_size=""
  if head_out=$(curl -sLI -H "Cache-Control: no-cache" "$url" 2>/dev/null); then
    total_size=$(echo "$head_out" | awk 'BEGIN{IGNORECASE=1} /^content-length:/{print $2}' | tail -n1 | tr -d '\r')
  fi

  if [[ ! "$total_size" =~ ^[0-9]+$ ]]; then
    curl -fLs -H "Cache-Control: no-cache" "$url" -o "$dest" >/dev/null 2>&1 &
    spinner $! "Downloading payload..."
    return $?
  fi

  local cols
  cols=$(terminal_cols)

  local w=$(( cols - 38 ))
  (( w > 60 )) && w=60
  (( w < 10 )) && w=10

  curl -fLs -H "Cache-Control: no-cache" "$url" -o "$dest" >/dev/null 2>&1 &
  local pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    local current_size=0
    if [[ -f "$dest" ]]; then
      current_size=$(wc -c < "$dest" 2>/dev/null || echo 0)
    fi

    awk -v c="$current_size" -v t="$total_size" -v cyan="$CYAN" -v dim="$DIM" -v rst="$RESET" -v width="$w" '
    BEGIN {
      pct = (t > 0) ? (c / t) * 100 : 0
      if (pct > 100) pct = 100
      filled = int((pct / 100) * width)
      empty = width - filled

      bar = ""
      for (i=0; i<filled; i++) bar = bar "█"
      for (i=0; i<empty; i++) bar = bar "░"

      c_mb = c / 1048576
      t_mb = t / 1048576

      printf "\r\033[K %s[..]%s [%s] %3d%% %s%5.1fM / %4.1fM%s", cyan, rst, bar, pct, dim, c_mb, t_mb, rst
    }'
    sleep 0.15
  done

  local exit_status=0
  wait "$pid" || exit_status=$?

  if [ $exit_status -eq 0 ]; then
    awk -v t="$total_size" -v grn="$GREEN" -v dim="$DIM" -v rst="$RESET" -v width="$w" '
    BEGIN {
      bar = ""
      for (i=0; i<width; i++) bar = bar "█"
      t_mb = t / 1048576
      printf "\r\033[K %s[OK]%s [%s] 100%% %s%5.1fM / %4.1fM%s\n", grn, rst, bar, dim, t_mb, t_mb, rst
    }'
  else
    printf "\r\033[K %b[ERR]%b Download failed.\n" "$RED" "$RESET"
  fi

  printf "\033[?25h" # Restore cursor
  return $exit_status
}

info "adb installation begins"


(
  yes | pkg update -y
) >/dev/null 2>&1 &
spinner $! "updating packages"


(
  pkg remove android-tools -y
) >/dev/null 2>&1 &
spinner $! "removing android-tools " 




(
  pkg install git -y
) >/dev/null 2>&1 &
spinner $! "installing git "




(
  git clone https://github.com/nohajc/termux-adb
) >/dev/null 2>&1 &
spinner $! "cloning repo"



(
  cd termux-adb &&
  chmod +x install.sh &&
  yes | bash install.sh &&
  mv /data/data/com.termux/files/usr/bin/termux-adb /data/data/com.termux/files/usr/bin/adb
) >/dev/null 2>&1 &
spinner $! "installing adb"

ok "adb installed"



(
  pkg install curl openssl php -y
) >/dev/null 2>&1 &
spinner $! "installing interpreter and dependencies "

(
  mkdir -p ~/php-adb

) >/dev/null 2>&1 &
spinner $! "creating workspace"




info "Downloading bypass.php"
download_with_progress "https://raw.githubusercontent.com/heppysingh/ubl_scripts/refs/heads/main/bypass.php" ~/php-adb/bypass.php
info "Downloading adb.php"
download_with_progress "https://raw.githubusercontent.com/heppysingh/ubl_scripts/refs/heads/main/adb.php" ~/php-adb/adb.php

goto_work() {
  cd ~/php-adb || return 1
}
goto_work 
echo -e '\033[1;36mNext Steps:\033[0m'
echo -e '  1. Run: \033[1mcd ~/php-adb\033[0m'
echo -e '  2. Connect the other device with OTG and enable USB debugging.'
echo -e '  3. Run: \033[1madb devices\033[0m'
echo -e '  4. If a serial number appears, run: \033[1mphp bypass.php\033[0m'
echo -e '  5. when it says  \033[1m-waiting for device\033[0m you have to go to mi unlock statusin dev options and add account'

