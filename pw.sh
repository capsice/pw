#!/bin/sh
# shellcheck shell=dash

#
# defaults
#

PASSGENLEN="48"
MAXPASSLEN="192"

PROGNAME="pw"
BASEDIR="$HOME/.local/share"
PWDIR="$BASEDIR/$PROGNAME"

OSTTY="$(stty -g)"

#
# globals
#

_resp=
_password=

#
# utility
#

normalize() {
  stty "$OSTTY"
  exit 0
}

die() {
  echo "$@" >&2
  exit 1
}

help() {
  cat <<- EOF
Usage:  $PROGNAME [ gen, set, get, del ] NAME
          perform [ gen, set, get, del ] on NAME

        $PROGNAME NAME
          alias for gen/get NAME

        $PROGNAME list
          list all saved passwords

        $PROGNAME export FILENAME?
          export vault to a compressed file

EOF
  exit "$1"
}

#
# passwords
#

ask_pass() {
  IFS=
  stty -echo
  set -o noglob
  echo -n "$1: "
  read -r _resp
  stty "$OSTTY"
  set +o noglob
  echo
}

ask_pass_twice() {
  local _tmp_resp _password_regex
  _password_regex="^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[^a-zA-Z0-9]).{8,}$"

  while :; do
    ask_pass "$1 (will not echo)"

    [ -z "$_resp" ] \
      && echo "password is empty, try again" \
      && continue

    [ ${#_resp} -gt $MAXPASSLEN ] \
      && echo "password is too long (>$MAXPASSLEN), try again" \
      && continue

    [ ${#_resp} -lt 6 ] \
      && echo "password is too short (<6), try again" \
      && continue

    echo "$_resp" | grep -qP "$_password_regex" || echo "! weak password!"

    _tmp_resp="$_resp"
    ask_pass "$1 (again)"

    [ "$_resp" = "$_tmp_resp" ] && break
    echo "passwords do not match, try again"
  done
}

ask_encryption_password() {
  if [ "$1" = "twice" ]; then
    ask_pass_twice "vault password?"
  else
    ask_pass "vault password?"
  fi
  _password="$_resp"
}

#
# encryption
#

encrypt() {
  echo "$1" | openssl pkeyutl -encrypt -pubin -inkey \
    "${PWDIR}/keys/pub.pem" -out "$2"
}

decrypt() {
  [ -z "$_password" ] && ask_encryption_password
  openssl pkeyutl -decrypt -inkey "${PWDIR}/keys/priv.pem" -in "$1" \
    -passin "pass:$_password" 2> /dev/null \
    || die "invalid vault password"
}

gen_private_key() {
  echo "* generating private key"
  [ -z "$_password" ] && ask_encryption_password twice
  openssl genpkey -algorithm RSA -aes256 -out "$PWDIR/keys/priv.pem" \
    -pkeyopt rsa_keygen_bits:4096 -pass "pass:$_password"
}

gen_public_key() {
  echo "* generating public key"
  [ -z "$_password" ] && ask_encryption_password
  openssl rsa -pubout -in "$PWDIR/keys/priv.pem" -out \
    "$PWDIR/keys/pub.pem" -passin "pass:$_password"
}

#
# main
#

trap normalize 1 2 3 6

test -e "$PWDIR" || mkdir -p "$PWDIR"
test -d "$PWDIR/keys" || mkdir -p "$PWDIR/keys"
test -e "$PWDIR/keys/priv.pem" || gen_private_key
test -e "$PWDIR/keys/pub.pem" || gen_public_key
test -d "$PWDIR/data" || mkdir -p "$PWDIR/data"

[ -z "$1" ] && help 1

do_set() {
  echo "* setting pw for $1"
  [ -e "$PWDIR/data/$1" ] \
    && die "$1 already exists. delete it with '$PROGNAME del $1'"
  ask_pass_twice "password for $1?"
  encrypt "$_resp" "$PWDIR/data/$1"
}

do_get() {
  echo "* obtaining pw for $1"
  test -e "$PWDIR/data/$1" || die "$1 not in database"
  decrypt "$PWDIR/data/$1"
}

do_gen() {
  echo "* generating pw for $1"
  [ -e "$PWDIR/data/$1" ] \
    && die "$1 already exists. delete it with '$PROGNAME del $1'"
  _resp="$(openssl rand -base64 "$PASSGENLEN")"
  encrypt "$_resp" "$PWDIR/data/$1"
  echo "* $1 : $_resp"
}

case "$1" in
  export)
    tar cvf "${2:-"pw-vault.tar.gz"}" -C "$BASEDIR" "$PROGNAME"
    ;;

  set)
    [ -z "$2" ] && help 1
    do_set "$2"
    ;;

  get)
    [ -z "$2" ] && help 1
    do_get "$2"
    ;;

  gen)
    [ -z "$2" ] && help 1
    do_gen "$2"
    ;;

  del)
    [ -z "$2" ] && help 1
    echo "* deleting pw for $1"
    test -e "$PWDIR/data/$2" || die "file does not exist"
    rm "$PWDIR/data/$2"
    ;;

  list)
    find "$PWDIR/data" -type f -exec basename {} \;
    ;;

  *)
    if [ -e "$PWDIR/data/$1" ]; then
      do_get "$1"
    else
      do_gen "$1"
    fi
    ;;
esac
