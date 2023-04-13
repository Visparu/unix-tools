#!/bin/bash

x=n d=n t=n a=n e=n n=n j=n
while [ $# -gt 0 ]; do
    case $1 in
        -x|--debug)
            x=y
            shift
            ;;
        -d|--download)
            d=y
            DOWNLOAD_LOCATION="$2"
            shift 2
            ;;
        -t|--download-target)
            t=y
            DOWNLOAD_TARGET="$2"
            shift 2
            ;;
        -a|--archive)
            a=y
            ARCHIVE_LOCATION="$2"
            shift 2
            ;;
        -e|--extract-dir)
            e=y
            EXTRACT_DIR="$2"
            shift 2
            ;;
        -n|--name)
            n=y
            ALTERNATIVE_NAME="$2"
            shift 2
            ;;
        -j|--java-alt-dir)
            j=y
            JAVA_ALTERNATIVE_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter passed: $1"
            exit 1
            ;;
    esac
done

# handle non-option arguments
if [[ $# -ne 0 ]]; then
    echo "$0: No unnamed parameter expected."
    exit 2
fi

# check for required variables
if [ -z ${DOWNLOAD_LOCATION+x} ] && [ -z ${ARCHIVE_LOCATION+x} ]; then
    echo "A download location or an archive location is required (-d|--download or -a|--archive)."
    exit 3
fi
if [ -z ${ALTERNATIVE_NAME+x} ]; then
    echo "An alternative name is required (-n|--name)."
    exit 4
fi

# substitute defaults
if [ -z ${EXTRACT_DIR+x} ]; then
    EXTRACT_DIR=extract
fi
if [ -z ${JAVA_ALTERNATIVE_DIR+x}]; then
    JAVA_ALTERNATIVE_DIR=/usr/lib/jvm
fi

# download JDK tar file
if [ ! -z ${DOWNLOAD_LOCATION+x} ]; then
    if [ -z ${ARCHIVE_LOCATION+x} ]; then
        ARCHIVE_LOCATION=$(basename $DOWNLOAD_LOCATION)
    fi
    wget $DOWNLOAD_LOCATION --quiet -O $ARCHIVE_LOCATION
    if [ ! -f $ARCHIVE_LOCATION ]; then
        echo "Download of JVM failed."
        exit 5
    fi
fi

# create extraction directory
mkdir -p $EXTRACT_DIR
if [ ! -z $(ls -A $EXTRACT_DIR) ]; then
    echo "Extract directory is not empty."
    exit 6
fi

# extract JDK files
tar -xzf $ARCHIVE_LOCATION -C $EXTRACT_DIR

# delete archive if JDK was downloaded
if [ $d = "y" ]; then
    rm $ARCHIVE_LOCATION
fi

FULL_ALTERNATIVE_PATH=$JAVA_ALTERNATIVE_DIR/$ALTERNATIVE_NAME

# move JDK to java-alternatives directory
rm -rf $FULL_ALTERNATIVE_PATH
mv $EXTRACT_DIR/$(ls -A $EXTRACT_DIR) $FULL_ALTERNATIVE_PATH
if [ ! -d $FULL_ALTERNATIVE_PATH ]; then
    echo "Moving the JDK to the alternative path failed."
    exit 7
fi

# remove extraction directory
rm -r $EXTRACT_DIR

# gather binary files for alternatives
BIN_DIRECTORY=$FULL_ALTERNATIVE_PATH/bin
BIN_FILES="$BIN_DIRECTORY/*"
JINFO_FILE=$JAVA_ALTERNATIVE_DIR/.$ALTERNATIVE_NAME.jinfo

# create .jinfo file
echo "name=$ALTERNATIVE_NAME" >$JINFO_FILE
echo "alias=$ALTERNATIVE_NAME" >>$JINFO_FILE
echo "priority=1000" >>$JINFO_FILE
echo "section=non-free" >>$JINFO_FILE
echo "" >>$JINFO_FILE
for BIN_FILE in $BIN_FILES
do
    BIN_FILE_BASENAME=$(basename $BIN_FILE)
    echo "jdk $BIN_FILE_BASENAME $BIN_FILE" >>$JINFO_FILE
done

# install alternatives
for BIN_FILE in $BIN_FILES
do
    BIN_FILE_BASENAME=$(basename $BIN_FILE)
    LINK=/usr/bin/$BIN_FILE_BASENAME
    update-alternatives --install $LINK $BIN_FILE_BASENAME $BIN_FILE 1000
done

update-java-alternatives --set $ALTERNATIVE_NAME
