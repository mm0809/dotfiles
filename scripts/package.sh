#!/usr/bin/env bash
TAR_FILE_NAME=dotfiles.tar.gz
ROOT_DIR=$(realpath $(dirname $0)/..)

tar -czf /tmp/$TAR_FILE_NAME -C $ROOT_DIR/.. dotfiles
mv /tmp/$TAR_FILE_NAME ./$TAR_FILE_NAME
