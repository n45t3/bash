#!/bin/bash

#############################################
# EPEL repo downloader script               #
# Author:  Bernard Schimmelpfennig          #
#                                           #
# Performs:                                 #
#    - download of appropriate EPEL version #
#    - addition of EPEL repo                #
#############################################

### FIELDS ###

sysvers=$(cat /etc/os-release | grep ^VERSION_ID= | cut -d'=' -f2 | sed -e 's|"||g' | cut -d'.' -f1) ;

declare -A pkgvers ;
pkgvers['7']='7-9' ;
pkgvers['6']='6-8' ;
pkgvers['5']='5-4' ;
pkgvers['4']='4-10' ;

pkgname="epel-release-${pkgvers[$sysvers]}.noarch.rpm" ;

### FUNCTIONS ###

log(){
   out=1 ;
   if [[ $3 ]] ; then out=$3 ; fi
   eval "echo \"LOG[${0}:${1}]## ${2}\" 1>&${3}" ;
}

err(){
   out=2 ;
   if [[ $3 ]] ; then out=$3 ; fi
   eval "echo \"ERR[${0}:${1}]## ${2}\" 1>&${3}" ;
}

usage(){
   echo "USAGE: $0 [options]" ;
   echo "OPTIONS:" ;
   echo "   -v | --verbose    output MOAR UZFUL LOGZ" ;
   echo "   -q | --quiet      output less useless logs" ;
   echo "   -s | --silent     output nothing" ;
   echo "   -h | --help       print this message and exit" ;
}

### MAIN ###

# streams for verbose output
exec 3>/dev/null ;
exec 4>/dev/null ;

# command line arguments parsing
while [[ ${1+def} ]] ; do
   if [[ $1 ]] ; then
      case $1 in
         # output level handling
         -v|--verbose)
            exec 3>&1 ;
            exec 4>&2 ;
            ;;
         -q|--quiet)
            exec 1>/dev/null ;
            exec 3>/dev/null ;
            exec 4>/dev/null ;
            ;;
         -s|--silent)
            exec 1>/dev/null ;
            exec 2>/dev/null ;
            exec 3>/dev/null ;
            exec 4>/dev/null ;
            ;;
            
         -h|--help)
            usage ;
            exit 0 ;
            ;;
         *)
            err 'parse_options' "invalid option: $1" ;
            ;;
      esac
   fi
   shift ;
done

cd /tmp ;
log '__main__' "performing package update" 3 ;
yum update -y ;
yum install -y wget ;

log '__main__' "downloading $pkgname" ;
case $sysvers in
   7)
      wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/${pkgname} && \
         log '__main__' "download finished successfuly" 3 || \
         err '__main__' "couldn't download $pkgname" 4 ;
      ;;
   *)
      wget http://download.fedoraproject.org/pub/epel/${sysvers}/$(uname -m)/${pkgname} && \
         log '__main__' "download finished successfuly" 3 || \
         err '__main__' "couldn't download $pkgname" 4 ;
      ;;
esac

log '__main__' "adding $pkgname to repo list" 3 ;
rpm -ivh ${pkgname} && \
   log '__main__' "repository added" 3 || \
   err '__main__' "failed to add repository" ;
log '__main__' "cleaning up" 3 ;
rm -f ${pkgname} ;

log '__main__' "performing package update" 3 ;
yum update -y ;