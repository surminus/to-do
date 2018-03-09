#!/bin/bash
#
# Script to manage to-do lists
#
### Set variables

# Set current to-do list
REPO_DIR="${HOME}/surminus/to-do"

###
if [[ $EDITOR == "" ]]; then
  EDITOR="vi"
fi

### Global variable
CURRENT_LIST="$REPO_DIR/to-do.md"
GIT_REPO="surminus/to-do"

### Functions

function _help {
  cat << EOF
  #############
      to-do
  #############

  Usage: to-do <command> [options]

  Commands:

  new        Create a new list. This also archives the previous "current" list.
  edit       Edit the current list.
  archive    Archive the current list.
  view       View the list in read-only mode.
  browse     Opens up a web browser for the Github repository.
  show       Displays the contents of the current list to STDOUT.
  git        Commit, push and pull from the repository.

EOF
}

function _git_help {
  cat << EOF
  #############
      to-do
  #############

  Usage: to-do git [option]

  Commands:

  update      Add latest changes and commit the result.
  fetch       Pull the latest list.
  push        Push the latest changes to the current branch.

EOF
}

if [[ -f $CURRENT_LIST ]]; then
  CURRENT_LIST_DATE=$(head -n1 $CURRENT_LIST |awk '{print $2}')
  if [[ ! $CURRENT_LIST_DATE =~ ^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$ ]]; then
    echo "Error! Does ${CURRENT_LIST} have incorrect date heading?"
    exit 1
  fi
fi

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
      echo "Current list only $(_current_list_age) days old!"
      echo "Do you still wish to archive?"
      echo "(y)es/(n)o"

      N=0
      while [ $N -eq 0 ]; do
        N=1
        read answer
        case $answer in
          y|yes) ;;
          n|no) exit 0 ;;
          *) echo "(y)es/(n)o"; N=0;;
        esac
      done
    fi

    echo "Archiving current list"

    if [[ -f "${ARCHIVE_DIR}/${CURRENT_LIST_DATE}.md" ]]; then
      echo "List already exists with that date in archive. Do you wish to"
      echo "replace, combine or quit?"
      echo "(r)eplace/(c)ombine/(q)uit"
      N=0
      while [ $N -eq 0 ]; do
        N=1
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
            echo "(r)eplace/(c)ombine/(q)uit"; N=0 ;;
        esac
      done
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
    N=0
    while [ $N -eq 0 ]; do
      read answer
      case $answer in
        y|yes) _new ;;
        n|no) exit 0 ;;
        *) echo "(y)es/(n)o"; N=1 ;;
      esac
    done
  fi
}

function _new_check {
  if [[ -f $CURRENT_LIST ]]; then
    if [[ "$(_current_list_age)" -lt 7  ]]; then
      echo "Current list is only $(_current_list_age) days old!"
      echo "Do you want to edit instead, or archive and create new?"
      echo "(e)dit/(a)rchive/(q)uit"

      N=0
      while [ $N -eq 0 ]; do
        N=1
        read answer
        case $answer in
          e|edit) _edit ;;
          n|new) _new ;;
          q|quit) exit 0 ;;
          *) echo "(e)dit/(a)rchive/(q)uit"; N=0 ;;
        esac
      done
    fi
  fi
}

function _edit_check {
  if [[ -f $CURRENT_LIST ]]; then
    if [[ $(_current_list_age) -ge 7 ]]; then
      echo "Current list is older than one week. Do you wish to edit"
      echo "this list or create a new one?"
      echo "(n)ew/(e)dit/(q)uit"

      N=0
      while [ $N -eq 0 ]; do
        N=1
        read answer

        case $answer in
          n|new) new ;;
          e|edit) edit ;;
          q|quit) exit 0 ;;
          *) echo "(n)ew/(e)dit/(q)uit"; N=0;;
        esac
      done
    fi
  fi
}

function _git {
  COMMAND=$1

  if [[ ! $COMMAND ]]; then
    _git_help
    exit 1
  fi

  cd $REPO_DIR

  case $COMMAND in
    update) git add . && git commit -m "Updated on $(date +%F_%H:%M:%S)" ;;
    push) git push origin HEAD ;;
    fetch) git pull ;;
    *) _git_help ;;
  esac
}

case $1 in
  archive) _archive ;;
  browse) _browse ;;
  edit) _edit_check && _edit ;;
  new) _new_check && _new ;;
  view) _view ;;
  show) _show ;;
  git) _git $2 ;;
  help) _help ;;
  *) _edit_check && _edit ;;
esac
