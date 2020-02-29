# dhost
dhost is a program for managing a dynamic DNS hostname database

## dhost Web Service
dhost.psgi is the dhost web service application. It accepts requests from HTTP clients using a simple REST API
and updates host records in the DNS database. The IP address set for a host entry can come from either a query parameter
or the addrss of the remote end of the HTTP connection. Clients are authenticated using credential information stored
in the database (just a simple shared secret mechanism is currently implemented).

## dhost administration tool
dhost.pl is the administration tool used for intializing the dhost database or adding new hosts and roles.

# License
dhost is Copyright 2020 by Stephen Cavilia

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
