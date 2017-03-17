#! /usr/bin/env perl

use feature qw(say);
use strict;
use warnings;

if ( -d "newdir" ) {
    system "rm -rf newdir";
}
chdir "dir" or die "chdir: $!";
if ( -d "p1" ) {
    system "rm -rf p1";
}
if ( -d "DEMO" ) {
    system "rm -rf DEMO";
}
system "mkdir -p p1/b1/c1/rev1";
system "mkdir -p p1/b1/c1/rev2";
system "touch p1/b1/c1/rev1/rev1.config";
system "touch p1/b1/c1/rev1/rev1.html";
system "touch p1/b1/c1/rev2/rev2.config";
system "touch p1/b1/c1/rev2/rev2.html";
system "touch p1/b1/c1/c1.config";
system "touch p1/b1/c1/c1.html";
system "echo  'c1 : 0% : 0% c11 c1 c1' > p1/p1.config";
system "touch p1/p1.html";


__DATA__
PROJECT:DEMO:p1
BLOCK:top:b1
CHECKLIST:DV:c1

      DEMO
    |-- DEMO.config
    |-- DEMO.html
    |-- top
    |   |-- DV
    |   |   |-- DV.config
    |   |   |--DV.html
    |   |   |-- rev1
    |   |   |   |-- rev1.config
    |   |   |   `-- rev1.html
    |   |   `-- rev2
    |   |       |-- rev2.config
    |   |       `-- rev2.html

  
