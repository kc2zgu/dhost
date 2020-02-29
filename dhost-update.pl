#!/usr/bin/perl

use strict;
use warnings;

use LWP::Simple;
use Getopt::Std;

sub usage {
    print "Usage: $0 -s api_server -h hostname -k secret [-a addr]\n";
    exit 2;
}

my %opts;
getopts('s:h:k:a:', \%opts);

unless (exists $opts{s} && exists $opts{h})
{
    usage();
}

my $addr = (exists $opts{a}) ? $opts{a} : 'client';

if (my $result = get("$opts{s}/host/$opts{h}/update?secret=$opts{k}&addr=$addr"))
{
    print $result;
    print "Updated hostname $opts{h}\n";
}
else
{
    print "Could not update $opts{h}\n";
    exit 1;
}
