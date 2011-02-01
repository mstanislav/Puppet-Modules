#!/usr/bin/perl

# Robin Sheat, 10/2/2009 <robin@kallisti.net.nz>

use strict;
use warnings;

use Nagios::Plugin;

my $np = Nagios::Plugin->new(shortname => "PUPPET");

my $maxdiff = $ARGV[0] * 60;

my ($filestate, $filemsg);
my ($procstate, $procmsg);

($filestate, $filemsg) = check_file();
($procstate, $procmsg) = check_proc();

my $msg = $filemsg . "; " . $procmsg;
my $state = $procstate + $filestate;

my $status = $state == 0 ? OK : CRITICAL;

$np->nagios_exit($status, $msg);

sub check_file {
        my $file = '/var/lib/puppet/state/state.yaml';
        return (1, "$file not found") if (! -e $file);
        my $mtime = (stat($file))[9];
        my $now = time;
        my $age = $now - $mtime;
        my $state;
        if ($age < $maxdiff) {
                $state = 0;
        } else {
                $state = 1;
        }
        my $msg = "state file is ".int($age/60)." minutes old";
        return ($state, $msg);
}

sub check_proc {
        my $pidfile = "/var/run/puppet/puppetd.pid";
        open my $fh, "<$pidfile"
                or return (1, "opening ".$pidfile." failed: $!");
        chomp(my $pid = <$fh>);
        close $fh;
        system("ps ax|egrep '^[ ]*\\b${pid}[^\\d]' > /dev/null");
        if ( $? == 0 ) {
                return (0, "process running");
        } else {
                return (1, "process not running");
        }
}
