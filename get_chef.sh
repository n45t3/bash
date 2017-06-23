#!/bin/bash

#############################################
# Chef packages downloader script           #
# Author:  Bernard Schimmelpfennig          #
#                                           #
# Performs:                                 #
#    - download of appropriate Chef product #
#############################################

### FIELDS ###
sysname=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2 | sed -e 's|"||g') ;
sysvers=$(cat /etc/os-release | grep ^VERSION_ID= | cut -d'=' -f2 | sed -e 's|"||g') ;
sysmajv=$(echo $sysvers | cut -d'.' -f1) ;

product= ;

pkgrepo='current' ;
pkgvers= ;
pkgname= ;
pkgaddr= ;

### CHEF PACKAGE MAPPINGS ###

declare -A pkgmng ;
pkgmng['ubuntu']="dpkg -i" ;
pkgmng['debian']="dpkg -i" ;
pkgmng['centos']="yum -y localinstall" ;
pkgmng['rhel']="yum -y localinstall" ;
pkgmng['sles']="zypper --no-gpg-checks --non-interactive in" ;

declare -A pkgend ;
pkgend['ubuntu']="deb" ;
pkgend['debian']="deb" ;
pkgend['centos']="rpm" ;
pkgend['rhel']="rpm" ;
pkgend['sles']="rpm" ;

declare -A pkgsys ;
pkgsys['ubuntu']="ubuntu" ;
pkgsys['debian']="debian" ;
pkgsys['centos']="el" ;
pkgsys['rhel']="el" ;
pkgsys['sles']="sles" ;

declare -A pkgset ;
pkgset['chef']="chef:chef" ;
pkgset['chefdk']="chefdk:chefdk" ;
pkgset['chef-server']="chef-server:chef-server-core" ;
pkgset['push-jobs-server']="opscode-push-jobs-server:opscode-push-jobs-server" ;
pkgset['push-jobs-client']="push-jobs-client:push-jobs-client" ;
pkgset['inspec']="inspec:inspec" ;
pkgset['supermarket']="supermarket:supermarket" ;

### FUNCTIONS ###

log(){
   out=1 ;
   if [[ $3 ]] ; then out=$3 ; fi
   eval "echo \"LOG[${0}::${1}]## ${2}\" 1>&${out}" ;
}

err(){
   out=2 ;
   if [[ $3 ]] ; then out=$3 ; fi
   eval "echo \"ERR[${0}::${1}]## ${2}\" 1>&${out}" ;
}

usage(){
   echo "USAGE: $0 [options] [package]" ;
   echo "OPTIONS:" ;
   echo "        --version    specifies desired package version" ;
   echo "                     CURRENT or sequence-based version string" ;
   echo "                     defaults to CURRENT" ;
   echo "   -r | --remove     removes specified chef product from the system" ;
   echo "   -v | --verbose    output MOAR UZFUL LOGZ" ;
   echo "   -q | --quiet      output less useless logs" ;
   echo "   -s | --silent     output nothing" ;
   echo "   -h | --help       print this message and exit" ;
   echo "PACKAGE:" ;
   echo "string belonging to the class:" ;
   echo " * chef              Chef Client" ;
   echo " * chefdk            Chef Development Kit" ;
   echo " * chef-server       Chef Server" ;
   echo " * push-jobs-server  Opscode Push Jobs Server" ;
   echo " * push-jobs-client  Opscode Push Jobs Client" ;
   echo " * inspec            InSpec Verifier" ;
   echo " * supermarket       Chef Supermarket" ;
}

prep_name(){
   pkg2=$(echo ${pkgset[$product]} | cut -d':' -f2) ;
   case ${pkgend[$sysname]} in
      deb)
         pkgname="${pkg2}_${pkgvers}-1_amd64.deb" ;
         ;;
      rpm)
         pkgname="${pkg2}-${pkgvers}-1.${pkgsys[$sysname]}${sysmajv}.$(uname -m).rpm" ;
         ;;
      *)
         err 'prep_name' "unknown binary format: ${pkgend[$sysname]}" ;
         exit 2 ;
         ;;
   esac
}

prep_link(){
   pkg1=$(echo ${pkgset[$product]} | cut -d':' -f1) ;
   pkg2=$(echo ${pkgset[$product]} | cut -d':' -f2) ;
   
   pkgaddr="https://packages.chef.io/files/${pkgrepo}/${pkg1}/${pkgvers}/${pkgsys[$sysname]}" ;
   case ${pkgend[$sysname]} in
      deb)
         pkgaddr="${pkgaddr}/${sysvers}" ;
         ;;
      rpm)
         pkgaddr="${pkgaddr}/${sysmajv}" ;
         ;;
      *)
         err 'prep_link' "unknown binary format: ${pkgend[$sysname]}" ;
         exit 2 ;
         ;;
   esac
   pkgaddr="${pkgaddr}/${pkgname}" ;
}

fetch_current(){
   log 'fetch_current' "downloading current specification for $product" 3 ;
   wget -q -O current "https://downloads.chef.io/${product}/current" ;
   if [[ ! -f current ]] ; then
      err 'fetch_current' "download failed, aborting" 4 ;
      exit 3 ;
   else
      log 'fetch_current' "download finished successfuly" 3 ;
   fi
   
   OFS=$IFS ;
   IFS=$(echo -en "\n\b") ;
   for line in $(cat current) ; do
      if [[ $line =~ product-heading ]] ; then
         pkgvers=$(echo $line | 
                     sed 's|.*product-heading">||' |
                     sed 's|.</h1.*||' |
                     cut -d'>' -f2 |
                     cut -d'<' -f1 |
                     sed "s|\s*||g") ;
         
         IFS=$OFS ;
         log 'fetch_current' "package version set to: $pkgvers" 3 ;
         log 'fetch_current' "cleaning up" 3 ;
         rm -f current ;
         return 0 ;
      fi
   done
   err 'fetch_current' "unable to specify current version for $product" 4 ;
   exit 4 ;
}

set_version(){
   arg=$(echo $1 | tr '[:upper:]' '[:lower:]') ;
   if [[ $arg == current ]] ; then
      log 'set_package_version' "version set to CURRENT" 3 ;
      pkgrepo=current ;
      return 0 ;
   fi
   
   if [[ $arg =~ ([0-9]+\.){2}[0-9]+ ]] ; then
      log 'set_package_version' "version set to $arg" 3 ;
      pkgvers=$arg ;
      pkgrepo=stable ;
      return 0 ;
   fi
   
   err 'set_package_version' "version not specified" ;
   err 'set_package_version' "argument passed: $arg" 4 ;
   err 'set_package_version' "resetting to CURRENT" 4 ;
   pkgrepo=current ;
   return 1 ;
}

### MAIN ###

# streams for verbose output
exec 3>/dev/null ;
exec 4>/dev/null ;

# command line arguments parsing
while [[ ${1+def} ]] ; do
   if [[ $1 ]] ; then
      case $1 in
         --version)
            set_version $2 && shift ;
            ;;
            
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

         --)
            shift ;
            return 0 ;
            ;;
         *)
            if [[ ! $2 ]] ; then
               break ;
            else
               err 'parse_options' "invalid option: $1" ;
            fi
            ;;
      esac
   fi
   shift ;
done
product=$1 ;

if [[ ! $product ]] ; then
   err '__main__' "product not specified" ;
   usage ;
   exit 2 ;
fi
if [[ $pkgrepo == 'current' ]] ; then
   fetch_current ;
fi

# package installation
log '__main__' "setting package name" 3 ;
prep_name ;

echo "LOG[${0}::__main__]## RUNNING WITH PARAMETERS:" 1>&3 ;
echo "                  * operating system: ${sysname}" ;
echo "                  * architecture: $(uname -r)" ;
echo "                  * product: ${product}" ;
echo "                  * version: ${pkgrepo}:${pkgvers}" ;
echo "                  * package: ${pkgname}" ;

cd /tmp ;

if [[ ! -f $chefdl ]] ; then
   prep_link ;
   log '__main__' "source URL: $pkgaddr" 3 ;
   wget -q $pkgaddr ;
   if [[ -f $pkgname ]] ; then
      log '__main__' "download finished successfuly" 3 ;
   else
      err '__main__' "download failed, aborting" 4 ;
      exit 2 ;
   fi
else
   log '__main__' "package already downloaded" 3 ;
fi

log '__main__' "installing package $pkgname" 3 ;
eval "${pkgmng[$sysname]} $pkgname && \
         log '__main__' \"package installed successfuly\" 3 || \
         { \
            err '__main__' \"installation failed, aborting\" 4 ; \
            exit 1 ; \
         }" ;
