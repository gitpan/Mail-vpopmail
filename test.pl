#!/usr/local/bin/perl

use strict;
use Mail::vpopmail;

unless(-f '/var/qmail/users/assign'){
	die "your assign file is not in /var/qmail/users/assign: you must fix this or edit this module\n";
}

# we expect this to fail, but not crash or anything evil.
my $vchkpw = Mail::vpopmail->new(cache => 0, debug => 0);
my $dir = $vchkpw->get(email => 'username@example.com', field => 'dir');

print "..code seems to be ok\n";
