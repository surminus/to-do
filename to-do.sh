#!/bin/bash
#
# Script to manage to-do lists
#
### Set variables

# Set current to-do list
REPO_DIR="${HOME}/surminus/to-do/"

###
if [[ $EDITOR == "" ]]; then
  EDITOR="vi"
fi

### Global variable
CURRENT_LIST="$REPO_DIR/to-do.md"
CURRENT_LIST_DATE=$(head -n1 $CURRENT_LIST |awk '{print $2}')
GIT_REPO="surminus/to-do"

### Functions

function _help {
  cat << EOF
  #############
      to-do
  #############

  Usage: to-do <command>

  Commands:

  new        Create a new list. This also archives the previous "current" list.
  edit       Edit the current list.
  archive    Archive the current list.
  view       View the list in read-only mode.
  browse     Opens up a web browser for the Github repository.
  show       Displays the contents of the current list to STDOUT.


EOF
}

# Age of current list in days, based upon the header
function _current_list_age {
  DATE_NOW=$(date +%s)
  CURRENT_LIST_DATE_EPOCH=$(date -j -f "%Y-%m-%d" "$CURRENT_LIST_DATE" +"%s")

  echo "($DATE_NOW - $CURRENT_LIST_DATE_EPOCH) / 60 / 60 / 24" |bc

}

function _archive {
  ARCHIVE_DIR="${REPO_DIR}/archive"

  test -d $ARCHIVE_DIR || mkdir $ARCHIVE_DIR

  if [[ -f $CURRENT_LIST ]]; then
    if [[ "$(_current_list_age)" -lt 7 ]]; then
      echo "Current list only $(_current_list_age) days old."
      echo "Do you still wish to archive?"
      echo "(y)es/(n)o"

      read answer
      case $answer in
        y|yes) ;;
        n|no) echo "Quitting" && exit 0 ;;
        *) echo "Invalid option" && exit 1 ;;
      esac
    fi

    echo "Archiving current list"

    if [[ -f "${ARCHIVE_DIR}/${CURRENT_LIST_DATE}.md" ]]; then
      echo "List already exists with that date in archive. Do you wish to"
      echo "replace, combine or quit?"
      echo "(r)eplace/(c)ombine/(q)uit"
      read replace

      case $replace in
        r|replace)
          rm -f "${ARCHIVE_DIR}/${CURRENT_LIST_DATE}.md" && \
          mv "${CURRENT_LIST}" "${ARCHIVE_DIR}/${CURRENT_LIST_DATE}.md" && \
          echo "Archived as ${ARCHIVE_DIR}/${CURRENT_LIST_DATE}.md"
          ;;
        c|combine)
          grep -v "${CURRENT_LIST_DATE}" "${CURRENT_LIST}" >> "${ARCHIVE_DIR}/${CURRENT_LIST_DATE}.md" && \
          rm -f "${CURRENT_LIST}" && \
          echo "Combined current list into ${ARCHIVE_DIR}/${CURRENT_LIST_DATE}.md"
          ;;
        q|quit)
          echo "Quitting" && exit 0
          ;;
        *)
          echo "Invalid option, quitting" && exit 1
          ;;
      esac
    else
      mv "${CURRENT_LIST}" "${ARCHIVE_DIR}/${CURRENT_LIST_DATE}.md" && \
      echo "Archived as ${ARCHIVE_DIR}/${CURRENT_LIST_DATE}.md"
    fi
  else
    echo "No current list exists"
  fi
}

function _view {
  test -f $CURRENT_LIST && view $CURRENT_LIST
}

function _browse {
  open "https://github.com/$GIT_REPO"
}

function _show {
  test -f $CURRENT_LIST && cat $CURRENT_LIST
}

function _new {
  _archive

  echo "## $(date +%Y-%m-%d)" > $CURRENT_LIST && \
    $EDITOR $CURRENT_LIST

  exit 0
}

function _edit {
  if [[ -f $CURRENT_LIST ]]; then
    $EDITOR $CURRENT_LIST || exit 1
    exit 0
  else
    echo "No current list. Shall I create one?"
    echo "(y)es/(n)o"
    read answer
    case $answer in
      y|yes) _new ;;
      n|no) echo "Quitting" && exit 0 ;;
      *) echo "Invalid command" && exit 1 ;;
    esac
  fi
}

function _new_check {
  if [[ "$(_current_list_older_than)" -lt 7  ]]; then
    echo "Current list is only $(_current_list_older_than) days old,"
    echo "do you want to edit instead, or archive and create new?"
    echo "(e)dit/(a)rchive/(q)uit"
    read answer
    case $answer in
      e|edit) _edit ;;
      n|new) _new ;;
      q|quit) exit 0 ;;
      *) exit 1 ;;
    esac
  fi
}

function _edit_check {
  if [[ $(_current_list_older_than) -ge 7 ]]; then
    echo "Current list is older than one week. Do you wish to edit"
    echo "this list or create a new one?"
    echo "(n)ew/(e)dit/(q)uit"

    read answer

    case $answer in
      n|new) _new ;;
      e|edit) _edit ;;
      q|quit) echo "Quitting" && exit 0 ;;
      *) exit 1 ;;
    esac
  fi
}

case $1 in
  archive) _archive ;;
  browse) _browse ;;
  edit) _edit ;;
  new) _new ;;
  view) _view ;;
  show) _show ;;
  *) _help ;;
esac
