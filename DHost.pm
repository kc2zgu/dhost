package DHost;

use strict;
use warnings;

use DBI;
use YAML;

sub _get_config {
    return YAML::LoadFile('dhost.conf');
}

sub open_database {
    my $dbh;

    my $conf = _get_config();
    my $dbfile = $conf->{database};
    
    unless (-f $dbfile)
    {
	print STDERR "Bootstrapping SQLite DB\n";
	$dbh = DBI->connect("dbi:SQLite:dbname=$dbfile");
	$dbh->do('CREATE TABLE roles (rolename, PRIMARY KEY (rolename))');
	$dbh->do('CREATE TABLE credentials (rolename, credtype, data, PRIMARY KEY (rolename, credtype), FOREIGN KEY (rolename) REFERENCES roles (rolename))');
	$dbh->do('CREATE TABLE hosts (host, PRIMARY KEY (host))');
	$dbh->do('CREATE TABLE role_auth (rolename, host, mode, PRIMARY KEY (rolename, host, mode), FOREIGN KEY (rolename) REFERENCES roles (rolename), FOREIGN KEY (host) REFERENCES hosts (host))');
	$dbh->do('CREATE TABLE records (host, type, data, PRIMARY KEY (host, type), FOREIGN KEY (host) REFERENCES hosts (host))');

 	$dbh->do('PRAGMA foreign_keys = ON');
    }
    else
    {
	$dbh = DBI->connect("dbi:SQLite:dbname=$dbfile");
 	$dbh->do('PRAGMA foreign_keys = ON');
    }
    return $dbh;
}

sub _commit_host_record {
    my ($key, $record, $data) = @_;

    my $conf = _get_config();
    open my $knotc, "|-", $conf->{knotc_path} or return -1;
    print $knotc "zone-begin $conf->{zone}\n";
    print $knotc "zone-unset $conf->{zone} $key $record\n";
    print $knotc "zone-set $conf->{zone} $key $conf->{ttl} $record $data\n";
    print $knotc "zone-commit $conf->{zone}\n";
    close $knotc;
}

sub _set_host_record {
    my ($db, $key, $record, $data) = @_;

    my $records = get_host_records($db, $key);
    if (exists $records->{$record} && $records->{$record} eq $data)
    {
	return 0;
    }
    
    $db->do('DELETE FROM records WHERE host = ? AND type = ?', undef,
	    $key, $record);
    my $ins = $db->do('INSERT INTO records (host, type, data) VALUES (?, ?, ?)', undef,
		      $key, $record, $data);
    if ($ins)
    {
	_commit_host_record($key, $record, $data);
    }
}

sub update_host_a {
    my ($db, $host, $ip) = @_;

    return _set_host_record($db, $host, 'A', $ip);
}

sub update_host_aaaa {
    my ($db, $host, $ip) = @_;

    return _set_host_record($db, $host, 'AAAA', $ip);
}

sub add_role {
    my ($db, $role) = @_;

    return $db->do('INSERT INTO roles (rolename) VALUES (?)', undef,
		   $role);
}

sub add_role_secret {
    my ($db, $role, $secret) = @_;

    return $db->do('INSERT INTO credentials (rolename, credtype, data) VALUES (?, ?, ?)', undef,
		   $role, 'secret', $secret);
}

sub add_host {
    my ($db, $host) = @_;

    return $db->do('INSERT INTO hosts (host) VALUES (?)', undef,
		   $host);
}

sub role_authorize_host {
    my ($db, $role, $host, $mode) = @_;

    return $db->do('INSERT INTO role_auth (rolename, host, mode) VALUES (?, ?, ?)', undef,
		   $role, $host, $mode);
}

sub is_authorized {
    my ($db, $host, $mode, %credentials) = @_;

    my @roles;
    if (exists $credentials{secret})
    {
	my $sth = $db->prepare('SELECT rolename, credtype, data FROM credentials WHERE credtype = ? AND data = ?');
	if ($sth->execute('secret', $credentials{secret}))
	{
	    while (my @cols = $sth->fetchrow_array)
	    {
		print STDERR "Matched role $cols[0]\n";
		push @roles, $cols[0];
	    }
	}
    }
    else
    {
	print STDERR "No more authentication methods to try\n";
	return 0;
    }

    for my $role(@roles)
    {
	print STDERR "Checking role $role $host $mode\n";
	my $sth = $db->prepare('SELECT rolename, host, mode FROM role_auth WHERE rolename = ? AND host = ? AND mode = ?');
	if ($sth->execute($role, $host, $mode))
	{
	    if ($sth->fetchrow_array)
	    {
		print STDERR "Role $role authorized\n";
		return 1;
	    }
	}
    }
    return 0;
}

sub get_host_records {
    my ($db, $host) = @_;

    my %records;
    my $sth = $db->prepare('SELECT type, data FROM records WHERE host = ?');
    if ($sth->execute($host))
    {
	while (my @cols = $sth->fetchrow_array)
	{
	    $records{$cols[0]} = $cols[1];
	}
    }

    return \%records;
}

1;
