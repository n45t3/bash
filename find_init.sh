#!/bin/bash

########################################
# Specify Provider script for Linux    #
# Author:  Bernard Schimmelpfennig     #
#                                      #
# Performs:                            #
#    - run several tests to determine  #
#      whether the instance runs under #
#      SysV init, SystemD, Upstart etc #
########################################

### FIELDS ###
initsys= ;
initcmd= ;

verbose= ;
testing=('test_lsof'
         'test_ps'
         'test_proc'
         'test_init')

### FUNCTIONS ###
log(){
   out=1 ;
   if [[ $3 ]] ; then out=$3 ; fi
   eval "echo \"LOG[${0}:${1}]## ${2}\" 1>&${out}" ;
}

err(){
   out=2 ;
   if [[ $3 ]] ; then out=$3 ; fi
   eval "echo \"ERR[${0}:${1}]## ${2}\" 1>&${out}" ;
}

usage(){
cat <<-EOH
USAGE: $0 [options]
OPTIONS:
   -s|--short        only print service provider name
   -l|--long         print whole command line call
   -h|--help         print this message and exit
   -v|--verbose      verboses output
EOH
}

parse_entry(){
   local tmp=$(beautify $1) ;
   log 'file_parser' "parsing $1" 3 ;
   tmp=$(follow_link $(stat_file $tmp)) ;
   echo $(beautify $1) ;
   log 'file_parser' "parsed as $tmp" 3 ;
}

stat_file(){
   log 'file_parser' "fetching file info" 3 ;
   echo $(stat $1 | grep File | sed -e "s|File:||" | sed "s| *||g" | sed "s|->|?|") ;
}

beautify(){
   log 'beautifier' "parsing $1" 3 ;
   local tmp=$1 ;
   if [[ $tmp =~ ^[A-Za-z0-9/\._\$@-] ]] ; then true ;
   else 
      tmp=${tmp:1:${#tmp}} ; 
      log 'beautifier' "  -> $tmp" 3 ;
   fi
   if [[ $tmp =~ [A-Za-z0-9\._\$@-]$ ]] ; then true ;
   else 
      tmp=${tmp:0:$(( ${#tmp} - 1 ))} ; 
      log 'beautifier' "  -> $tmp" 3 ;
   fi
   echo $tmp ;
}

follow_link(){
   if [[ $1 =~ .*\?.* ]] ; then
      local cuttmp=$(echo $1 | cut -d'?' -f2) ;
      log 'onsymlink' "following symlink: $cuttmp" 3 ;
      echo $(parse_entry $cuttmp) ;
   else echo $1 ; 
   fi
}

test_lsof(){
   if [[ $(which lsof) ]] ; then
      log 'lsof_test' "lsof found at $(which lsof)" 3 ;
      initsys=$(lsof -a -p 1 -d txt -F pcn | \
                grep ^c | sed "s|^c||") ;
      initcmd=$(parse_entry \
                $(lsof -a -p 1 -d txt -F pcn | \
                  grep ^n | sed "s|^n||")) ;
   fi
}

test_ps(){
   if [[ $(which ps) ]] ; then
      initsys=$(ps -p 1 -o command | tail -n 1 | cut -d' ' -f1) ;
      initcmd=$(which $initsys) ;
   fi
}

test_proc(){
   if [[ -e /proc/1/comm ]] ; then
      initsys=$(cat /proc/1/comm) ;
      inticmd=$(which $initsys) ;
   fi
}

test_init(){
   if [[ $(which stat) ]] ; then
      initcmd=$(parse_entry /sbin/init) ;
      initsys=$(echo $initcmd | rev | cut -d'/' -f1 | rev) ;
   fi
}

parse_opts(){
   while [[ ${1+def} ]] ; do
      if [[ $1 ]] ; then
         case $1 in
            -l|--long)
               verbose=true ;
               ;;
            -s|--short)
               verbose= ;
               ;;
            -v|--verbose)
               exec 3>&2 ;
               ;;
            -h|--help)
               usage ;
               ;;
         esac
      fi
      shift ;
   done
}

### MAIN ###
parse_opts $1 ;

for t in ${testing[@]} ; do
   eval $t ;
   if [[ $initsys ]] ; then
      if [[ $verbose == 'true' ]] ; then
         echo $initcmd ;
      else echo $initsys ;
      fi
      exit 0 ;
   fi
done ;

echo 'unknown' ;
exit 1 ;
