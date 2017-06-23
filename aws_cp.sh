#!/bin/bash

### FIELDS ###

target= ;
bucket= ;
source= ;
output= ;
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
USAGE: $0 [from|to] bucket [source-destination pairs]
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

set_target(){
   target=$(echo $1 | tr '[:upper:]' '[:lower:]') ;
   if [[ $target == 'from' || $target == 'to' ]] ; then
      return 0 ;
   fi
   target= ;
   return 1 ;
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
   output=$(echo $1 | cut -d':' -f2) ;
   isfile=$(echo $1 | cut -d':' -f3) ;
   
   if [[ $source && \
         $output && \
         ( ! $isfile || \
           $isfile =~ [DdFf] ) ]] ; then
      return 0 ;
   fi ;
   
   source= ;
   output= ;
   isfile= ;
   return 1 ;
}

copy_from(){
   if [[ ! -e $output ]] ; then
      warn 'get_files' "no file or folder: $output, creating..." ;
      mkdir -p $output ;
      if [[ $isfile =~ [Ff] ]] ; then
         local tmp=$(echo $output | rev | cut -d'/' -f1 | rev) ;
         rmdir $tmp ;
      fi
   fi
   aws s3 cp $bucket/$source $output --recursive ;
}

copy_to(){
   aws s3 sync $source $bucket/$output --recursive ;
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

set_target $1 && shift || target=from ;
set_bucket $1 && shift || {
   err '__main__' "invalid bucket: $1" ;
   exit 2 ;
}

for arg in $@ ; do
   set_pair $arg && \
      eval "copy_$target" || \
      err '__main__' "invalid argument: $arg" ;
done