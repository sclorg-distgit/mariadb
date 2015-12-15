#!/bin/sh

/usr/lib/rpm/perl.prov $* | \
    grep -v -e "perl(th" \
    -e "perl(lib::mtr" -e "perl(lib::v1/mtr" -e "perl(mtr" -e "perl(My::"
