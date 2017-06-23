#!/bin/bash

### FIELDS ###
bucket= ;
source= ;
target= ;
isfile= ;

### OUTPUT ###

log(){
   out=1 ;
   if [[ $3 ]] ; then out=$3 ; fi
   eval "echo \"LOG[${0}:${1}]## ${2}\" 1>&${out}" ;
}

warn(){
   out=1 ;
   if [[ $3 ]] ; then out=$3 ; fi
   eval "echo \"WARN[${0}:${1}]## ${2}\" 1>&${out}" ;
}

err(){
   out=2 ;
   if [[ $3 ]] ; then out=$3 ; fi
   eval "echo \"ERR[${0}:${1}]## ${2}\" 1>&${out}" ;
}

### FUNCTIONS ###

usage(){
cat >> 1 <<-EOF
USAGE: $0 bucket [source-destination pairs]
BUCKET:
   aws-style s3 link to the bucket (s3://.*)
SOURCE-DESTINATION PAIRS:
   list of strings describing pairs (.*:.*):
   where both source and destination are:
   - relative location of file in the \$BUCKET file tree
     can specify either a single file or a whole directory 
   - absolute or relative location in the file system
     can specify either a single file or a whole directory
EOF
}

set_bucket(){
   if [[ $1 =~ ^s3:// ]] ; then
      bucket=$1 ;
      return 0 ;
   fi ;
   bucket= ;
   return 1 ;
}

set_pair(){
   source=$(echo $1 | cut -d':' -f1) ;
   target=$(echo $1 | cut -d':' -f2) ;
   isfile=$(echo $1 | cut -d':' -f3) ;
   
   if [[ $source && \
         $target && \
         ( ! $isfile || \
           $isfile =~ [DdFf] ) ]] ; then
      return 0 ;
   fi ;
   
   source= ;
   target= ;
   isfile= ;
   return 1 ;
}

get_files(){
   if [[ ! -e $target ]] ; then
      warn 'get_files' "no file or folder: $target, creating..." ;
      mkdir -p $target ;
      if [[ $isfile =~ [Ff] ]] ; then
         local tmp=$(echo $target | rev | cut -d'/' -f1 | rev) ;
         rmdir $tmp ;
      fi
   fi
   aws s3 cp $bucket/$source $target --recursive ;
}

### MAIN ###

if [[ $1 == '-h' || $1 == '--help' ]] ; then
   usage ;
   exit ;
fi

if [[ ! $(which aws) ]] ; then
   err '__main__' "AWS CLI not found, consider configuring your \$PATH variable" ;
   exit 1 ;
fi

set_bucket $1 || {
   err '__main__' "invalid bucket: $1" ;
   exit 2 ;
}
shift ;

for arg in $@ ; do
   set_pair $arg && \
      get_files || \
      err '__main__' "invalid argument: $arg" ;
done