#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib $FindBin::Bin;

use DHost;

use File::Basename qw/basename/;
use Math::Random::Secure qw/irand/;
use Data::Validate::IP qw/is_ipv4 is_ipv6/;

my $dhost_db;

sub cmd_init {
    print "Initialized database\n";

    return 0;
}

sub gen_secret {
    my $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

    my $secret;
    for (1..20)
    {
	$secret .= substr($chars, irand(length $chars), 1);
    }
    return $secret;
}

sub cmd_add_role {
    my ($rolename) = @_;

    my $secret = gen_secret();

    print "Generated secret for role $rolename: $secret\n";

    unless (DHost::add_role($dhost_db, $rolename))
    {
	print STDERR "Adding role $rolename failed\n";
	return 1;
    }
    unless (DHost::add_role_secret($dhost_db, $rolename, $secret))
    {
	print STDERR "Adding secret to role $rolename failed\n";
	return 1;
    }

    print "Added role $rolename\n";
    return 0;
}

sub cmd_add_host {
    my ($host) = @_;

    unless (DHost::add_host($dhost_db, $host))
    {
	print STDERR "Adding host $host failed\n";
    }

    print "Added host $host\n";
    return 0;
}

sub cmd_add_auth {
    my ($role, $host, $mode) = @_;

    unless (defined $mode)
    {
	print "Using default mode update\n";
	$mode = 'update';
    }

    unless (DHost::role_authorize_host($dhost_db, $role, $host, $mode))
    {
	print STDERR "Authorizing $host for $role failed\n";
	return 1;
    }

    print "Authorized $mode on $host for role $role\n";
    return 0;
}

sub cmd_set_host {
    my ($host, $ip) = @_;

    if (is_ipv4($ip))
    {
	unless (DHost::update_host_a($dhost_db, $host, $ip))
	{
	    print STDERR "A record for $host $ip already exists\n";
	}
	return 0;
    }
    elsif (is_ipv6($ip))
    {
	unless (DHost::update_host_aaaa($dhost_db, $host, $ip))
	{
	    print STDERR "AAAA record for $host $ip already exists\n";
	}
	return 0;
    }
    else
    {
	print STDERR "$ip is not a valid IPv4 or IPv6 address\n";
	return 1;
    }
}

sub cmd_get_host {
    my ($host) = @_;

    my $records = DHost::get_host_records($dhost_db, $host);
    if (keys %$records)
    {
	for my $type(sort keys %$records)
	{
	    print "$host IN $type $records->{$type}\n";
	}
	return 0;
    }
    else
    {
	print STDERR "No records for host $host\n";
	return 1;
    }
}

my %commands = (init => \&cmd_init,
		add_role => \&cmd_add_role,
		add_host => \&cmd_add_host,
		add_auth => \&cmd_add_auth,
		set_host => \&cmd_set_host,
		get_host => \&cmd_get_host);

if (@ARGV)
{
    my $cmd = shift @ARGV;
    if (exists $commands{$cmd})
    {
	$dhost_db = DHost::open_database();
	unless (defined $dhost_db)
	{
	    print STDERR "Erorr opening database\n";
	    exit 2;
	}

	$dhost_db->begin_work();
	my $ret = $commands{$cmd}->(@ARGV);
	if ($ret == 0)
	{
	    $dhost_db->commit();
	}
	else
	{
	    print STDERR "$cmd failed, aborting database changes\n";
	    $dhost_db->rollback();
	}
	exit $ret;
    }
    else
    {
	print "Unknown command $cmd\n";
	exit 1;
    }
}
else
{
    my $prg = basename $0;
    print "Usage: $prg command args\n";
    exit 1;
}
