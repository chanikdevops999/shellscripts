#!/bin/sh
#
# SCRIPT: bzr.sh
# AUTHOR: Janos Gyerik <janos.gyerik@gmail.com>
# DATE:   2008-05-03
# REV:    1.0.D (Valid are A, B, D, T and P)
#               (For Alpha, Beta, Dev, Test and Production)
#
# PLATFORM: Not platform dependent
#
# PURPOSE: Various miscellaneous repository manipulations via bzr+ssh:
#	   * remote repository operations:
#		* only with bzr+ssh repositories, for path traversal
#		* list projects
#		* checkout projects or update local folder if exists
#	   * local copy operations:
#		* show status of local copy
#		* update local copy
#	   * note:
#		* as of 1.4rc1, there is no (reasonable) way to distinguish 
#		  between an unmodified local copy with a local copy that has
#		  local commits. This becomes a problem when updating local
#		  copies with local commits. When updating a local copy with
#		  local commits, the changes in local commits, the changes
#		  made after that, and the changes in the repository will all
#		  blend together. That is, the local changes made after the
#		  local commits will be extremely difficult to see.
#		  The workaround to this is to not keep around uncommitted
#		  changes in a working directory that has local commits.
#		  FYI, this behavior affects both update and checkout commands,
#		  as they both automatically update existing repositories.
#
# REV LIST:
#        DATE:	DATE_of_REVISION
#        BY:	AUTHOR_of_MODIFICATION   
#        MODIFICATION: Describe what was modified, new features, etc-
#
#
# set -n   # Uncomment to check your syntax, without execution.
#          # NOTE: Do not forget to put the comment back in or
#          #       the shell script will not execute!
# set -x   # Uncomment to debug this shell script (Korn shell only)
#

usage() {
    test $# = 0 || echo $@
    echo "Usage: $0 [OPTION]... cmd"
    echo "Check out all projects in a Bazaar repository into the specified directory."
    echo
    echo "Options:"
    echo "      --ssh BZRHOST BZRROOT   Set the ssh host and bzrroot, default = $bzrhost $bzrroot"
    echo "      --brief                 Brief output, default = $brief"
    echo "      --local                 Do not try to connect repository, default = $brief"
    echo "  -h, --help                  Print this help"
    echo
    echo "Remote repository commands:"
    echo "  checkout, co"
    echo "  list, ls"
    echo
    echo "Local copy commands:"
    echo "  status, stat, st"
    echo "  update, up"
    echo
    exit 1
}

neg=0
args=
#arg=
#flag=off
#param=
bzrhost=
bzrroot=
brief=off
local=off
while [ $# != 0 ]; do
    case $1 in
    -h|--help) usage ;;
    !) neg=1; shift; continue ;;
#    -f|--flag) test $neg = 1 && flag=off || flag=on ;;
#    -p|--param) shift; param=$1 ;;
    --brief) test $neg = 1 && brief=off || brief=on ;;
    --local) test $neg = 1 && local=off || local=on ;;
    --ssh)
	test $# -gt 1 || usage
	shift; bzrhost=$1
	shift; bzrroot=$1 
	;;
#    --) shift; while [ $# != 0 ]; do args="$args \"$1\""; shift; done; break ;;
    -?*) usage "Unknown option: $1" ;;
    *) args="$args \"$1\"" ;;  # script that takes multiple arguments
#    *) test "$arg" && usage || arg=$1 ;;  # strict with excess arguments
#    *) arg=$1 ;;  # forgiving with excess arguments
    esac
    shift
    neg=0
done

eval "set -- $args"  # save arguments in $@. Use "$@" in for loops, not $@

workfile=/tmp/.bzr.sh-$$
trap 'rm -f $workfile; exit 1' 1 2 3 15

repolistcmd="find $bzrroot -name .bzr | while read d; do test -d \$d/branch && echo \$d; done | sed -e s:/.bzr::"

case "$1" in
    checkout|co)
	test "$bzrhost" || usage 'Use --ssh to specify bzrhost and bzrroot!'
	test "$bzrroot" || usage 'Use --ssh to specify bzrhost and bzrroot!'
	test "$2" && localbase=$2 || localbase=.
	ssh $bzrhost "$repolistcmd" > $workfile
	exec 5<$workfile
	while read rdir<&5; do
	    if test "$rdir" = "$bzrroot"; then
		pdir=$localbase/$(basename $rdir)
	    else
		pdir=$localbase/$(echo $rdir | sed -e "s:^$bzrroot/::")
	    fi
	    if test -d $pdir; then
		echo "Updating project in $pdir ..."
		echo
		(cd $pdir; bzr update)
	    else
		echo "Checking out bzr+ssh://$bzrhost$rdir into $pdir ..."
		echo
		mkdir -p $(dirname $pdir)
		bzr co bzr+ssh://$bzrhost$rdir $pdir
	    fi
	done
	;;
    list|ls)
	test "$bzrhost" || usage 'Use --ssh to specify bzrhost and bzrroot!'
	test "$bzrroot" || usage 'Use --ssh to specify bzrhost and bzrroot!'
	test "$2" && localbase=$2 || localbase=.
	ssh $bzrhost "$repolistcmd"
	;;
    status|stat|st)
	shift
	test "$1" || eval 'set -- .'
	bzr_status() {
	    test -d "$1" || return
	    cd "$1"
	    if test -d .bzr; then
		tmp=/tmp/.bzr-status-$$-1
		trap 'rm -f $tmp; exit 1' 1 2 3 15
		if test $local = on; then
		    bzr info > $tmp 2>/dev/null
		    ret_info=1
		else
		    bzr info -v > $tmp 2>/dev/null
		    ret_info=$?
		fi
		revision=r$(grep -o '  [0-9][0-9]* revision' $tmp | head -n 1 | cut -f3 -d' ')
		repository=$(sed -e '/checkout of / p' -e d $tmp | sed -e 's/.*branch: \(.*\)/\1/')
		spacing="	"
		printstring="$spacing$revision$spacing$repository"
		if test $ret_info != 0; then
		    flag1=-
		elif grep -F 'Branch is out of date' $tmp >/dev/null; then
		    flag1=O
		else
		    flag1=\*
		fi
		if ! bzr diff >/dev/null; then
		    flag2=M
		else
		    flag2=\*
		fi
		echo "$flag1$flag2$printstring"
		rm -f $tmp
	    else
		for i in *; do
		    (bzr_status $i)
		done
	    fi
	}
	for i in "$@"; do
	    (bzr_status $i)
	done
	;;
    update|up)
	shift
	test "$1" || eval 'set -- .'
	bzr_up() {
	    test -d "$1" || return
	    cd "$1"
	    if test -d .bzr; then
		if test $brief = on; then
		    bzr info | sed -e '/checkout of / p' -e d | sed -e 's/.*branch: \(.*\)/\1/'
		    bzr up >/dev/null
		else
		    echo -n Local copy:' '
		    pwd
		    bzr info | grep -F 'checkout of branch'
		    bzr up
		    echo
		fi
	    else
		for i in *; do
		    (bzr_up $i)
		done
	    fi
	}
	for i in "$@"; do
	    (bzr_up $i)
	done
	;;
esac

rm -f $workfile
    
# eof
