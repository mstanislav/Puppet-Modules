#!/usr/bin/perl -w
# Note that it maybe the case that you do actually want "SHOW STATUS" even with
# mysqld 5.0.2, then specify query line with '-q' option like
#   ./check_mysqld.pl -p foo -f -u nagios -A uptime,threads_connected,slow_queries,open_tables -H nagios -q 'SHOW STATUS' 
#
# define command{
#  command_name check_mysqld
#  command_line $USER1$/check_mysqld.pl -H $HOSTADDRESS$ -u $ARG1$ -p $ARG2$ -a uptime,threads_connected,questions,slow_queries,open_tables -w ",,,," -c ",,,,"
# }
#
# define service {
#  use                     service-critical
#  hostgroup_name          mysql
#  service_description     MYSQLD
#  check_command           check_mysqld!foo!apples
# }
#
# Examples of command-line use:
# /usr/lib/nagios/plugins/check_mysqld.pl -v
# /usr/lib/nagios/plugins/check_mysqld.pl -p foo -f -u nagios -a uptime,threads_connected,questions,slow_queries,open_tables -A threads_running,innodb_row_lock_time_avg  -w ",,,," -c ",,,,>25" -H nagios -v

use strict;

# default mysql hostname, port, database, user and password, see NOTES above
my $HOSTNAME= 'localhost';
my $PORT=     3306;
my $DATABASE= '';
my $USERNAME= 'mysql';
my $PASSWORD= '';

# Add path to additional libraries if necessary
use lib '/mysql/modules';
use lib '/usr/lib/nagios/plugins';
use lib '/usr/lib64/nagios/plugins';
use utils qw(%ERRORS $TIMEOUT);

# uncomment two lines below and comment out two above lines if you do not have nagios' utils.pm
# my $TIMEOUT = 20;
# my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# ============= MAIN PROGRAM CODE - DO NOT MODIFY BELOW THIS LINE ==============

use Getopt::Long qw(:config no_ignore_case);
use DBI;

my $o_host=     undef;                  # hostname
my $o_port=     undef;                  # port
my $o_dbname=   undef;                  # database
my $o_login=    undef;          # Database user
my $o_passwd=   undef;          # Password
my $o_help=     undef;          # help option
my $o_verb=     undef;          # verbose mode
my $o_version=  undef;          # version info option
my $o_variables=undef;          # list of variables for warn and critical
my @o_varsL=    ();             # array from above list
my $o_perfvars= undef;          # list of variables to include in perfomance data
my @o_perfvarsL=();             # array from above list
my $o_warn=     undef;          # warning level option
my @o_warnL=    ();             # array of warn data processing threshold 
my $o_crit=     undef;          # Critical level option
my @o_critL=    ();             # array of critical data processing thresholds 
my $o_perf=     undef;          # Performance data option
my $o_timeout=  undef;          # Timeout to use - note that normally timeout is take from nagios anyway
my $o_replication=undef;        # Normal replication status value, if something else then you'll see CRITICAL error
my $o_slave=    undef;          # Normal slave status, if something else then you'll see CRITICAL error
my $o_query=    undef;          # Query to execute instead of default SHOW STATUS

my $Version='0.9';
my $dbh= undef;                 # DB connection object

sub p_version { print "check_mysqld version : $Version\n"; }

sub print_usage {
   print "Usage: $0 [-v] [-H <host> [-P <port>]] [-u <username>] [-q <query>] [-p <password>] [-a <mysql variables> -w <variables warning thresholdz> -c <variables critical thresholds>] [-A <performance output variables>] [-s <expected slave status>] [-r <expected replication status>] [-f] [-t <timeout>] [-V]\n";
}

sub help {
   print "\nMySQL Database Monitor for Nagios version ",$Version,"\n";
   print " by William Leibzon - william(at)leibzon.org\n\n";
   print "This monitoring script connects to database, does 'SELECT VERSION' and then\n";
   print "'SHOW STATUS' or 'SHOW GLOBAL STATUS' (for version 5.0.2 or newer of mysql)\n";
   print "or other query you specify with '-q'. It then allows to select variables\n";
   print "from 'SHOW STATUS' and check them against critical and warning thresholds(s)\n";
   print "Status data can also be used for performance output.\n\n";
   print_usage();
   print <<EOT;
 -v, --verbose
   print extra debugging information
 -h, --help
   Print this detailed help screen
 -H, --hostname=ADDRESS
   Hostname or IP Address to check
 -P, --port=INTEGER
   MySQL port number (default: 3306)
 -D, --database=STRING
   Database name to login to
   (Default is none and you almost never need to change this)
 -u, --username=STRING
   Connect using the indicated username (Default is 'mysql')
 -p, --password=STRING
   Use the indicated password to authenticate the connection
   (Default is empty password)
   ==> IMPORTANT: THIS FORM OF AUTHENTICATION IS NOT SECURE!!! <==
   Your clear-text password will be visible as a process table entry
 -p, --password=PASSWD
   Password to use when connecting to database (Default is empty password)
 -q, --query=STRING
   Specify query to do instead of 'SHOW STATUS'. This is useful to check
   some other specialized mysql commands and tables. In order to work
   returned data should be similar to one from "SHOW STATUS", i.e. 
   table with two columns.
 -a, --variables=STRING,[STRING,[STRING...]]
   List of variables as found in 'SHOW STATUS' which should be monitored. 
   The list can be arbitrarily long and the default (if option is not used)
   is not to monitor any variable. You can repeat same variable if you need
   it checked for both below and above thresholds.
 -w, --warn=STR[,STR[,STR[..]]]
   This option can only be used if '--variables' (or '-a') option above
   is used and number of values listed here must exactly match number
   of variables specified with '-a'. The values specify warning threshold
   for when Nagios should send WARNING alert. These values are usually
   numbers and can have the following prefix modifiers:
      > - warn if data is above this value (default for numeric values)
      < - warn if data is below this value (must be followed by number)
      = - warn if data is equal to this value (default for non-numeric values)
      ! - warn if data is not equal to this value
      ~ - do not check this data (must not be followed by number)
      ^ - for numeric values this disables check that warning < critical
   Threshold values can also be specified as range in two forms:
      num1:num2  - warn if data is outside range i.e. if data<num1 or data>num2
      \@num1:num2 - warn if data is in range i.e. data>=num1 && data<=num2
-c, --crit=STR[,STR[,STR[..]]]
   This option can only be used if '--variables' (or '-a') option above
   is used and number of values listed here must exactly match number of
   variables specified with '-a'. The values specify critical threshold
   for when Nagios should send CRITICAL alert. The format is exactly same
   as with -w option except no '^' prefix.
 -s, --slave=status
   If slave status (normally it is 'OFF') is anything other then what is
   specified with, then CRITICAL alert would be sent. This can also be done
   with '=' option so seperate option is kept for backward compatibility 
 -r, --replication=status
   If replication status (normally it is NULL) is anything other then what
   is specified with this option, then CRITICAL alert would be sent.
 -f, --perfparse
   This should only be used with '-a', '-s' or '-r' and causes to output
   variable data not only as part of main status line but also as
   perfparse compatible output (for graphing, etc).
 -A, --perfvars=STRING,[STRING,[STRING...]]
   This allows to list variables which values will go only into perfparse
   output (and not for threshold checking). A special value of '*' allows
   to output all variables from 'SHOW STATUS' or 'SHOW GLOBAL STATUS'.
 -V, --version
   Prints version number
EOT
print "\nThere are no required arguments. By default, the local 'mysql' database";
print "from a server listening on MySQL standard port 3306 will be checked\n\n";
}

# For verbose output
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

# Return true if arg is a number
sub isnum {
  my $num = shift;
  if (defined($num) && $num =~ /^[-|+]?((\d+\.?\d*)|(^\.\d+))$/ ) { return 1 ;}
  return 0;
}

# help function used when checking data against critical and warn values
sub check_threshold {
    my ($attrib, $data, $th_array) = @_;
    my $mod = $th_array->[0];
    my $lv1 = $th_array->[1];
    my $lv2 = $th_array->[2];

    # verb("debug check_threshold: $mod : ".(defined($lv1)?$lv1:'')." : ".(defined($lv2)?$lv2:''));
    return "" if !defined($lv1) || ($mod eq '' && $lv1 eq '');
    return " " . $attrib . " is " . $data . " = " . $lv1 if $mod eq '=' && $data eq $lv1;
    return " " . $attrib . " is " . $data . " != " . $lv1 if $mod eq '!' && $data ne $lv1;
    return " " . $attrib . " is " . $data . " > " . $lv1 if $mod eq '>' && $data>$lv1;
    return " " . $attrib . " is " . $data . " >= " . $lv1 if $mod eq '>=' && $data>=$lv1;
    return " " . $attrib . " is " . $data . " < " . $lv1 if $mod eq '<' && $data<$lv1;
    return " " . $attrib . " is " . $data . " <= " . $lv1 if $mod eq '<=' && $data<=$lv1;
    return " " . $attrib . " is " . $data . " outside range $lv1 .. $lv2" if $mod eq ':' && ($data<$lv1 || $data>$lv2);
    return " " . $attrib . " is " . $data . " in range $lv1..$lv2" if $mod eq '@' && $data>=$lv1 && $data<=$lv2;
    return "";
}

# this is a help function called when parsing threshold options data
sub parse_threshold {
    my ($thin) = @_;

    # link to an array that holds processed threshold data
    # array: 1st is type of check, 2nd is value2, 3rd is value2, 4th is option
    my $th_array = [ '', undef, undef, '' ];
    my $th = $thin;
    my $at = '';

    $at = $1 if $th =~ s/^(\^?[@|>|<|=|!]?~?)//; # check mostly for my own threshold format
    $th_array->[3]='^' if $at =~ s/\^//; # deal with ^ option
    $at =~ s/~//; # ignore ~ if it was entered
    if ($th =~ /^\:([-|+]?\d+\.?\d*)/) { # :number format per nagios spec
        $th_array->[1]=$1;
        $th_array->[0]=($at !~ /@/)?'>':'<=';
    }
    elsif ($th =~ /([-|+]?\d+\.?\d*)\:$/) { # number: format per nagios spec 
        $th_array->[1]=$1;
        $th_array->[0]=($at !~ /@/)?'<':'>=';
    }
    elsif ($th =~ /([-|+]?\d+\.?\d*)\:([-|+]?\d+\.?\d*)/) { # nagios range format
        $th_array->[1]=$1;
        $th_array->[2]=$2;
        if ($th_array->[1] > $th_array->[2]) {
                print "Incorrect format in '$thin' - in range specification first number must be smaller then 2nd\n";
                print_usage();
                exit $ERRORS{"UNKNOWN"};
        }
        $th_array->[0]=($at !~ /@/)?':':'@';
    }
    if (!defined($th_array->[1])) {
        $th_array->[0] = ($at eq '@')?'<=':$at;
        $th_array->[1] = $th;
    }
    if ($th_array->[0] =~ /[>|<]/ && !isnum($th_array->[1])) {
        print "Numeric value required when '>' or '<' are used !\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
    }
    # verb("debug parse_threshold: $th_array->[0] and $th_array->[1]");
    $th_array->[0] = '=' if !$th_array->[0] && !isnum($th_array->[1]) && $th_array->[1] ne '';
    $th_array->[0] = '>' if !$th_array->[0] && isnum($th_array->[1]);
    return $th_array;
}

# ultimately this function will check if warn threshold is "less" then critical
# (with "less" meaning different things depending on format of data)
sub threshold_specok {
    my ($warn_thar,$crit_thar) = @_;
    return 1 if isnum($warn_thar->[1]) && isnum($crit_thar->[1]) &&
                $warn_thar->[0] eq $crit_thar->[0] &&
                $warn_thar->[3] !~ /\^/ &&
              (($warn_thar->[1]>=$crit_thar->[1] && $warn_thar->[0] !~ /</) ||
               ($warn_thar->[1]<=$crit_thar->[1] && $warn_thar->[0] =~ /</));
    return 0;
}

# parse command line options
sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'v'     => \$o_verb,            'verbose'       => \$o_verb,
        'h'     => \$o_help,            'help'          => \$o_help,
        'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
        'P:i'   => \$o_port,            'port:i'        => \$o_port,
        'D:s'   => \$o_dbname,          'database:s'    => \$o_dbname,
        'u:s'   => \$o_login,           'username:s'    => \$o_login,
        'p:s'   => \$o_passwd,          'password:s'    => \$o_passwd,
        't:i'   => \$o_timeout,         'timeout:i'     => \$o_timeout,
        'V'     => \$o_version,         'version'       => \$o_version,
        'r:s'   => \$o_replication,     'replication:s' => \$o_replication,
        's:s'   => \$o_slave,           'slave:s'       => \$o_slave,
        'a:s'   => \$o_variables,       'variables:s'   => \$o_variables,
        'c:s'   => \$o_crit,            'critical:s'    => \$o_crit,
        'w:s'   => \$o_warn,            'warn:s'        => \$o_warn,
        'f:s'   => \$o_perf,            'perfparse:s'   => \$o_perf,
        'A:s'   => \$o_perfvars,        'perfvars:s'    => \$o_perfvars,
        'q:s'   => \$o_query,           'query:s'       => \$o_query,
    );
    if (defined($o_help)) { help(); exit $ERRORS{"UNKNOWN"} };
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"} };

    # below code is common for number of my plugins, including check_snmp_?, netstat, etc
    # it is mostly compliant with nagios threshold specification (except use of '~')
    # and adds number of additional format options using '>','<','!','=' prefixes
    my (@ar_warnLv,@ar_critLv);
    @o_perfvarsL=split( /,/ , lc $o_perfvars ) if defined($o_perfvars) && $o_perfvars ne '*';
    if (defined($o_warn) || defined($o_crit) || defined($o_variables)) {
        if (defined($o_variables)) {
          @o_varsL=split( /,/ , lc $o_variables );
          if (defined($o_warn)) {
             $o_warn.="~" if $o_warn =~ /,$/;
             @ar_warnLv=split( /,/ , lc $o_warn );
          }
          if (defined($o_crit)) {
             $o_crit.="~" if $o_crit =~ /,$/;
             @ar_critLv=split( /,/ , lc $o_crit );
          }
        }
        else {
          print "Specifying warning and critical levels requires '-a' parameter with list of STATUS variables\n";
          print_usage();
          exit $ERRORS{"UNKNOWN"};
        }
        if (scalar(@ar_warnLv)!=scalar(@o_varsL) || scalar(@ar_critLv)!=scalar(@o_varsL)) {
          printf "Number of specified warning levels (%d) and critical levels (%d) must be equal to the number of attributes specified at '-a' (%d). If you need to ignore some attribute do it as ',,'\n", scalar(@ar_warnLv), scalar(@ar_critLv), scalar(@o_varsL);
          verb("Warning Levels: ".join(",",@ar_warnLv));
          verb("Critical Levels: ".join(",",@ar_critLv));
          print_usage();
          exit $ERRORS{"UNKNOWN"};
        }
        for (my $i=0; $i<scalar(@o_varsL); $i++) {
          $o_warnL[$i] = parse_threshold($ar_warnLv[$i]);
          $o_critL[$i] = parse_threshold($ar_critLv[$i]);
          if (threshold_specok($o_warnL[$i],$o_critL[$i])) {
                 print "All numeric warning values must be less then critical (or greater then when '<' is used)\n";
                 print "Note: to override this check prefix warning value with ^\n";
                 print_usage();
                 exit $ERRORS{"UNKNOWN"};
           }
        }
    }

    # if (scalar(@o_varsL)==0 && scalar(@o_perfvarsL)==0) {
    #   print "You must specify list of attributes with either '-a' or '-A'\n";
    #   print_usage();
    #   exit $ERRORS{"UNKNOWN"};
    #    }

    $HOSTNAME = $o_host if defined($o_host);
    $PORT     = $o_port if defined($o_port);
    $DATABASE = $o_dbname if defined($o_dbname);
    $USERNAME = $o_login if defined($o_login);
    $PASSWORD = $o_passwd if defined($o_passwd);
    $TIMEOUT  = $o_timeout if defined($o_timeout);
}

# Get the alarm signal (just in case nagios screws up)
$SIG{'ALRM'} = sub {
     $dbh->disconnect() if defined($dbh);
     print ("ERROR: Alarm signal (Nagios time-out)\n");
     exit $ERRORS{"UNKNOWN"};
};

########## MAIN #######

check_options();

# Check global timeout if plugin screws up
if (defined($TIMEOUT)) {
  verb("Alarm at $TIMEOUT");
  alarm($TIMEOUT);
}
else {
  verb("no timeout defined : $o_timeout + 10");
  alarm ($o_timeout+10);
}

verb("connecting to database '$DATABASE' on host '$HOSTNAME' with user '$USERNAME'");
my $dsn = "DBI:mysql:";
$dsn.="database=$DATABASE" if $DATABASE;
$dsn.=":";
$dsn.="host=$HOSTNAME" if $HOSTNAME;
$dsn.=":port=$PORT";
$dbh = DBI->connect($dsn,$USERNAME,$PASSWORD, { PrintError => 0 } );
if (!$dbh) {
    print "CRITICAL ERROR - Unable to connect to database '$DATABASE' on server '$HOSTNAME' on port $PORT with user '$USERNAME' - $DBI::errstr\n";
    exit $ERRORS{"CRITICAL"};
}

my $db_command="SELECT VERSION()";
verb ("Mysql Query: $db_command");
my $sth=$dbh->prepare($db_command);
if (!$sth->execute()) {
    print "CRITICAL ERROR - Unable to execute '$db_command' on server '$HOSTNAME' connected as user '$USERNAME' - $DBI::errstr\n";
    exit $ERRORS{"CRITICAL"};
}

my ($mysql_version)=$sth->fetchrow_array();
if ($sth->err) {
    print "CRITICAL ERROR - Error retrieving data for '$db_command' on server '$HOSTNAME' connected as user '$USERNAME' - $sth->err\n";
    exit $ERRORS{"CRITICAL"};
}
$sth->finish();

my @mvnum=(0,0,0);
@mvnum=($1,$2,$3) if $mysql_version =~ /(\d+)\.(\d+)\.(\d+)/;
verb("Mysql Data: $mysql_version | Numeric: $mvnum[0].$mvnum[1].$mvnum[2]");
if (defined($o_query)) {
  $db_command=$o_query;
}
elsif ($mvnum[0]>5 || ($mvnum[0]==5 && ($mvnum[1]>0 || ($mvnum[1]==0 && $mvnum[2]>1)))) {
   $db_command = 'SHOW GLOBAL STATUS';
}
else {
   $db_command = 'SHOW STATUS';
}

verb("Mysql Query: $db_command");
$sth=$dbh->prepare($db_command);
if (!$sth->execute()) {
    print "CRITICAL ERROR - Unable to execute '$db_command' on server '$HOSTNAME' connected as user '$USERNAME' - $DBI::errstr\n";
    exit $ERRORS{"CRITICAL"};
}

my %dataresults;
my $statuscode = "OK";
my $statusinfo = "";
my $statusdata = "";
my $perfdata = "";
my $mysql_vname;
my $mysql_value;
my $chk = "";
my $i;

# load all data from mysql into internal hash array
$dataresults{$_} = [undef, 0, 0] foreach(@o_varsL);
$dataresults{$_} = [undef, 0, 0] foreach(@o_perfvarsL);
while (($mysql_vname,$mysql_value)=$sth->fetchrow_array()) {
    $mysql_vname =~ tr/[A-Z]/[a-z]/ ;
    $mysql_value='NULL' if !defined($mysql_value);
    verb("Mysql Data: $mysql_vname = $mysql_value");
    $dataresults{$mysql_vname}[0] = $mysql_value if exists($dataresults{$mysql_vname});
    if (defined($o_perfvars) && $o_perfvars eq '*') {
       $dataresults{$mysql_vname} = [$mysql_value, 0, 0];
       push @o_perfvarsL, $mysql_vname;
    }
    if (defined($o_replication) && $mysql_vname eq 'rpl_status') {
        $statuscode = 'CRITICAL' if $o_replication && ($mysql_value eq 'NULL' || $mysql_value ne $o_replication);
        $statusinfo .= " rpl_status=" . $mysql_value;
    }
    if (defined($o_slave) && $mysql_vname eq 'slave_running') {
        $statuscode = 'CRITICAL' if $o_slave && ($mysql_value eq 'NULL' || $mysql_value ne $o_slave);
        $statusinfo .= " slave_running=" . $mysql_value;
    }
}
if ($sth->err) {
    $statuscode = 'CRITICAL';
    $statusinfo = "error $sth->err during value retrival " . $statusinfo;
}
$sth->finish();
$dbh->disconnect();

# main loop to check if warning & critical attributes are ok
for ($i=0;$i<scalar(@o_varsL);$i++) {
  if (defined($dataresults{$o_varsL[$i]}[0])) {
    if ($chk = check_threshold($o_varsL[$i],lc $dataresults{$o_varsL[$i]}[0],$o_critL[$i])) {
        $dataresults{$o_varsL[$i]}[1]++;
        $statuscode = "CRITICAL";
        $statusinfo .= $chk;
    }
    elsif ($chk = check_threshold($o_varsL[$i],lc $dataresults{$o_varsL[$i]}[0],$o_warnL[$i])) {
        $dataresults{$o_varsL[$i]}[1]++;
        $statuscode="WARNING" if $statuscode eq "OK";
        $statusinfo .= $chk;
    }
    if ($dataresults{$o_varsL[$i]}[1]==0) {
          $dataresults{$o_varsL[$i]}[1]++;
          $statusdata .= " " . $o_varsL[$i] . "=" . $dataresults{$o_varsL[$i]}[0];
    }
    if (defined($o_perf) && $dataresults{$o_varsL[$i]}[2]==0) {
          $dataresults{$o_varsL[$i]}[2]++;
          $perfdata .= " " . $o_varsL[$i] . "=" . $dataresults{$o_varsL[$i]}[0];
    }
  }
  else {
        $statuscode="CRITICAL";
        $statusinfo .= " $o_varsL[$i] data is missing";
  }
}

# add data for performance-only attributes
for ($i=0;$i<scalar(@o_perfvarsL);$i++) {
  if (defined($dataresults{$o_perfvarsL[$i]}[0]) && $dataresults{$o_perfvarsL[$i]}[2]==0) {
    $perfdata .= " " . $o_perfvarsL[$i] . "=" . $dataresults{$o_perfvarsL[$i]}[0];
    $dataresults{$o_perfvarsL[$i]}[2]++;
  }
}

# now output the results
print "MYSQL " . $mysql_version . " " . $statuscode . $statusinfo;
print " -" . $statusdata if $statusdata;
print " |" . $perfdata if $perfdata;
print "\n";

# end exit
exit $ERRORS{$statuscode};
