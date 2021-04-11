use strict;
use warnings;

use FindBin;
use lib $FindBin::Bin;

use DHost;

use Plack::Request;
use Data::Validate::IP qw/is_ipv4 is_ipv6/;

sub dhost_psgi_run {
    my $env = shift;

    my $db = DHost::open_database();
    unless (defined $db)
    {
        return [500, ['Content-Type' => 'text/plain'], ['Error opening database']];
    }

    my $req = Plack::Request->new($env);
    my @path_parts = grep {length $_} split '/', $req->path_info;

    if ($path_parts[0] eq 'host')
    {
        return dhost_host_run($db, $req, @path_parts);
    }
    else
    {
        my @body;

        for my $key (sort keys %$env)
        {
            push @body, "$key: $env->{$key}\n";
        }

        push @body, "Path components: [@path_parts]\n";

        for my $q(keys %{$req->parameters})
        {
            push @body, "Query param: $q = @{[$req->parameters->{$q}]}\n";
        }

        return [200, ['Content-Type' => 'text/plain'], \@body];
    }
}

sub dhost_host_run {
    my ($db, $req, @path_parts) = @_;

    my $host = $path_parts[1];
    my $action = $path_parts[2];

    my @body;

    push @body, "Host name: $host\n";

    my ($auth_type, $auth_cred);
    if ($req->parameters->{secret})
    {
        $auth_type = 'secret';
        $auth_cred = $req->parameters->{secret};
        push @body, "Using secret authentication with credential $auth_cred\n";
    }

    unless (defined $auth_type)
    {
        push @body, "No authentication provided\n";
    }

    if (defined $action)
    {
        push @body, "Action: $action\n";
        my $result = 200;
        if ($action eq 'update')
        {
            my $rec = $req->parameters->{rec} // 'addr';
            if ($rec eq 'addr')
            {
                my $addr;
                my $reqaddr = $req->parameters->{addr};
                if ($reqaddr eq 'client')
                {
                    $addr = $req->env->{HTTP_X_FORWARDED_FOR} // $req->address;
                }
                else
                {
                    $addr = $reqaddr;
                }
                if (DHost::is_authorized($db, $host, 'update', ($auth_type => $auth_cred)))
                {
                    if (is_ipv4($addr))
                    {
                        push @body, "Updating $host IPv4 to $addr\n";
                        DHost::update_host_a($db, $host, $addr);
                    }
                    elsif (is_ipv6($addr))
                    {
                        push @body, "Updating $host IPv6 to $addr\n";
                        DHost::update_host_aaaa($db, $host, $addr);
                    }
                    else
                    {
                        push @body, "Address $addr is invalid\n";
                        $result = 400;
                    }
                }
                else
                {
                    push @body, "Not authorized to update $host\n";
                    $result = 403;
                }
            } elsif ($rec eq 'txt')
            {
                my $txt = $req->parameters->{addr};
                if (DHost::is_authorized($db, $host, 'update', ($auth_type => $auth_cred)))
                {
                    DHost::update_host_txt($db, $host, $txt);
                }
                else
                {
                    push @body, "Not authorized to update $host\n";
                    $result = 403;
                }
            }
        }
        else
        {
            push @body, "Unknown action $action\n";
            $result = 400;
        }
        return [$result, ['Content-Type' => 'text/plain'], \@body];
    }
    else
    {
        my $records = DHost::get_host_records($db, $host);
        if (keys %$records)
        {
            for my $type(sort keys %$records)
            {
                push @body, "$host: $type = $records->{$type}\n";
            }
        }
        else
        {
            push @body, "No address for $host\n";
        }
        return [200, ['Content-Type' => 'text/plain'], \@body];
    }
}

return \&dhost_psgi_run;
