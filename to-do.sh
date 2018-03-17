#!/bin/bash
#
# Script to manage to-do lists
#
### Set variables

# Where the repository is installed
REPO_DIR="${HOME}/surminus/to-do"

# Name of Github user used by this list
GIT_USER="surminus"

# Name of the repository for this list
REPO_NAME="to-do"

# Whether to render to HTML by default
ALWAYS_HTML_RENDER="true"

# How many minutes between checking for remote changes
# Default: 1 day
REMOTE_GITHUB_CHECK_MINUTES=1400

###
if [[ $EDITOR == "" ]]; then
  EDITOR="vi"
fi

### Global variable
CURRENT_LIST="$REPO_DIR/to-do.md"
GIT_REPO_URL="https://github.com/${GIT_USER}/${REPO_NAME}"
GITHUB_PAGES_URL="https://${GIT_USER}.github.io/${REPO_NAME}/to-do.html"

### Functions

function _help {
  cat << EOF
  #############
      to-do
  #############

  Usage: to-do <command> [options]

  If no command is provided then the default action is to edit.

  Commands:

  new        Create a new list. This also archives the previous "current" list.
  edit       Edit the current list.
  archive    Archive the current list.
  view       View the list in read-only mode.
  browse     Opens up a web browser for the current list in Github.
  show       Displays the contents of the current list to STDOUT.
  git        Commit, push and pull from the repository.
  html       Render list to HTML using pandoc, and browse in Github pages.

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

function _html_help {
  cat << EOF
  #############
      to-do
  #############

  Usage: to-do html [option]

  Commands:

  render      Render the list to HTML at to-do.html.
  browse      View the list in Github pages for the repository.

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

function _git {
  COMMAND=$1

  if [[ ! $COMMAND ]]; then
    _git_help
    exit 1
  fi

  cd $REPO_DIR

  case $COMMAND in
    update) git add to-do.md to-do.html archive/ && git commit -m "Updated on $(date +%F_%H:%M:%S)" ;;
    push) git push origin HEAD ;;
    fetch) git pull ;;
    *) _git_help ;;
  esac
}

function _git_interactive_update {
  cd $REPO_DIR
  if ! git diff --quiet to-do.md to-do.html archive/; then
    echo "Do you want to push changes to Github? (y)es/(n)o"
    read answer
    N=0
    while [ $N -eq 0 ]; do
      N=1
      case $answer in
        y|yes) _git update && _git push ;;
        n|no) ;;
        *) echo "(y)es/(n)o"; N=0 ;;
      esac
    done
  fi
}

function _git_remote_check {
  test -d "${HOME}/.to-do" || mkdir "${HOME}/.to-do"
  GIT_CHECK_FILE="${HOME}/.to-do/git-status"

  test -f $GIT_CHECK_FILE || touch $GIT_CHECK_FILE

  # If the file is older than one day then check for updates.
  if test $(find ${GIT_CHECK_FILE} -mmin +${REMOTE_GITHUB_CHECK_MINUTES}); then
    cd $REPO_DIR
    echo "Checking for updates"
    git remote update && git status -uno | grep -q 'Your branch is up to date' || git pull origin HEAD
    touch $GIT_CHECK_FILE
  fi
}

function _html {
  OPTION=$1

  if [[ -z $OPTION ]]; then
    _html_help && exit 1
  fi

  case $OPTION in
    render)
      if ! which pandoc >/dev/null; then
        echo "Must install pandoc:"
        echo "brew install pandoc"
        exit 1
      fi

      cd $REPO_DIR && \
        pandoc -f markdown -t html to-do.md > to-do.html
      ;;
    browse)
      open "${GITHUB_PAGES_URL}"
      ;;
    *) _html_help && exit 1 ;;
  esac
}

function _archive {
  ARCHIVE_DIR="${REPO_DIR}/archive"

  test -d $ARCHIVE_DIR || mkdir $ARCHIVE_DIR

  if [[ -f $CURRENT_LIST ]]; then
    if [[ "$(_current_list_age)" -lt 7 ]] && [[ $1 != "force" ]]; then
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
  _git_remote_check
  test -f $CURRENT_LIST && view $CURRENT_LIST
}

function _browse {
  open "${GIT_REPO_URL}"
}

function _show {
  _git_remote_check
  test -f $CURRENT_LIST && cat $CURRENT_LIST
}

# Default functions that happen after new or edit
function _post {
  if [[ $ALWAYS_HTML_RENDER == "true" ]]; then
    _html render
  fi

  _git_interactive_update

  exit 0
}

function _new {
  _archive "force"

  echo "## $(date +%Y-%m-%d)" > $CURRENT_LIST && \
    $EDITOR $CURRENT_LIST

  _post
}

function _edit {
  if [[ -f $CURRENT_LIST ]]; then
    $EDITOR $CURRENT_LIST || exit 1
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

  _post
}

function _new_check {
  _git_remote_check

  if [[ -f $CURRENT_LIST ]]; then
    if [[ "$(_current_list_age)" -lt 7  ]]; then
      echo "Current list is only $(_current_list_age) days old!"
      echo "Do you want to archive and create new, or edit instead?"
      echo "(n)ew/(e)dit/(q)uit"

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
  _git_remote_check

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

case $1 in
  archive) _archive ;;
  browse) _browse ;;
  edit) _edit_check && _edit ;;
  new) _new_check && _new ;;
  view) _view ;;
  show) _show ;;
  git) _git $2 ;;
  html) _html $2 ;;
  help) _help ;;
  *) _edit_check && _edit ;;
esac
