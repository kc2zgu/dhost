#!/usr/bin/perl

use strict;
use warnings;

use LWP::Simple;
use Getopt::Std;

sub usage {
    print "Usage: $0 -s api_server -h hostname -k secret [-a addr] [-r record]\n";
    exit 2;
}

my %opts;
getopts('s:h:k:a:r:', \%opts);

unless (exists $opts{s} && exists $opts{h})
{
    usage();
}

my $addr = (exists $opts{a}) ? $opts{a} : 'client';

my @params;
push @params, "secret=$opts{k}";
push @params, "addr=$addr";
push @params, "rec=$opts{r}" if exists $opts{r};

my $params = join '&', @params;

if (my $result = get("$opts{s}/host/$opts{h}/update?$params"))
{
    print $result;
    print "Updated hostname $opts{h}\n";
}
else
{
    print "Could not update $opts{h}\n";
    exit 1;
}
