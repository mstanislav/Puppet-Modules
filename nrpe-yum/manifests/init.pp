class nrpe {
    if ($architecture == "i386") {
        $libpath = "lib"
    } else {
        $libpath = "lib64"
    }
    
    package { [ "nagios-nrpe", "perl-Nagios-Plugin", "nagios-plugins-nrpe", "perl-DBI" ]:
        ensure  => present,
        require => Yumrepo["epel"];
    }

    service { "nrpe":
        ensure    => running,
        enable    => true,
        require => [ Package["nagios-nrpe"], Package["nagios-plugins-nrpe"] ],
        subscribe => File["/etc/nagios/nrpe.cfg"];
    }

    file { 
        "/etc/nagios/nrpe.cfg":
            ensure  => present,
            owner   => "nagios",
            group   => "nagios",
            mode    => "0664",
            content => template("nrpe/nrpe.cfg.erb"),
            require => Package["nagios-nrpe"];

        "/usr/$libpath/nagios/plugins":
            ensure   => directory,
            owner    => "root",
            group    => "root",
            mode     => "0755",
            source   => "puppet:///modules/nrpe/plugins",
            recurse  => true,
            require  => Package["nagios-plugins-nrpe"];
    }
}
