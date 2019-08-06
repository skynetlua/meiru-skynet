#!/bin/sh

PACKAGE=lua-iconv
VERSION=7

DIRNAME=$PACKAGE-$VERSION
TGZNAME=$DIRNAME.tar.gz

rm -f $TGZNAME
mkdir $DIRNAME

cp -r debian $DIRNAME/
#rm -rf $DIRNAME/debian/.svn

cp -r COPYING Makefile README luaiconv.c test_iconv.lua $DIRNAME

tar -czf $TGZNAME $DIRNAME

#cd $DIRNAME dpkg-buildpackage -rfakeroot
#cd ..

rm -rf $DIRNAME
tar -tzf $TGZNAME
